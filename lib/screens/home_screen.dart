import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techsphere/models/user_model.dart';
import 'package:techsphere/screens/chat_screen.dart';
import 'package:techsphere/screens/settings_screen.dart';
import 'package:techsphere/widgets/progress_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class HomeScreen extends StatefulWidget {
  final String currentUserId;
  const HomeScreen({super.key, required this.currentUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Future<QuerySnapshot>? _searchResults;
  String _photoUrl = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPrefs();
    // Mark user online
    FirebaseFirestore.instance
        .collection('usersChat')
        .doc(widget.currentUserId)
        .update({'isOnline': true}).catchError((_) {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    FirebaseFirestore.instance
        .collection('usersChat')
        .doc(widget.currentUserId)
        .update({
      'isOnline': false,
      'lastSeen': Timestamp.now(),
    }).catchError((_) {});
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _photoUrl = prefs.getString('photoUrl') ?? '';
    });
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    setState(() {
      _searchResults = FirebaseFirestore.instance
          .collection('usersChat')
          .where('nickname', isGreaterThanOrEqualTo: query.trim())
          .where('nickname',
              isLessThanOrEqualTo: '${query.trim()}\uf8ff')
          .get();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'TechSphere',
          style: TextStyle(fontFamily: 'Signatra', fontSize: 28),
        ),
        actions: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            backgroundImage:
                _photoUrl.isNotEmpty ? CachedNetworkImageProvider(_photoUrl) : null,
            child: _photoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.lightBlueAccent)
                : null,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadPrefs()),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chats'),
            Tab(icon: Icon(Icons.search), text: 'People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConversationsTab(currentUserId: widget.currentUserId),
          _PeopleTab(
            currentUserId: widget.currentUserId,
            searchController: _searchController,
            searchResults: _searchResults,
            onSearch: _search,
            onClear: () {
              _searchController.clear();
              setState(() => _searchResults = null);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: Conversations
// ─────────────────────────────────────────────

class _ConversationsTab extends StatelessWidget {
  final String currentUserId;
  const _ConversationsTab({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(currentUserId)
          .collection('chats')
          .orderBy('lastTimestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return circularProgress();
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined,
                    size: 100, color: Colors.lightBlueAccent),
                SizedBox(height: 16),
                Text(
                  'No conversations yet.\nSearch for people to start chatting!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final lastMsg = data['lastMessage'] as String? ?? '';
            final ts = data['lastTimestamp'] as Timestamp?;
            final otherId = data['otherUserId'] as String? ?? '';
            final otherName = data['otherUserName'] as String? ?? '';
            final otherPhoto = data['otherUserPhoto'] as String? ?? '';
            final unread = data['unreadCount'] as int? ?? 0;
            final timeStr = ts != null
                ? timeago.format(ts.toDate())
                : '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                backgroundImage: otherPhoto.isNotEmpty
                    ? CachedNetworkImageProvider(otherPhoto)
                    : null,
                child: otherPhoto.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              title: Text(
                otherName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0 ? Colors.black87 : Colors.grey,
                  fontWeight:
                      unread > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(timeStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unread',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    currentUserId: currentUserId,
                    receiverId: otherId,
                    receiverName: otherName,
                    receiverAvatar: otherPhoto,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: People search
// ─────────────────────────────────────────────

class _PeopleTab extends StatelessWidget {
  final String currentUserId;
  final TextEditingController searchController;
  final Future<QuerySnapshot>? searchResults;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  const _PeopleTab({
    required this.currentUserId,
    required this.searchController,
    required this.searchResults,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by nickname…',
              prefixIcon: const Icon(Icons.person_pin),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onSubmitted: onSearch,
            onChanged: (v) {
              if (v.isEmpty) onClear();
            },
            textInputAction: TextInputAction.search,
          ),
        ),
        Expanded(
          child: searchResults == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group,
                          color: Colors.lightBlueAccent, size: 120),
                      SizedBox(height: 16),
                      Text(
                        'Search for users',
                        style: TextStyle(
                            color: Colors.lightBlueAccent,
                            fontSize: 24,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : FutureBuilder<QuerySnapshot>(
                  future: searchResults,
                  builder: (context, snap) {
                    if (!snap.hasData) return circularProgress();
                    final results = snap.data!.docs
                        .where((doc) => doc.id != currentUserId)
                        .toList();
                    if (results.isEmpty) {
                      return const Center(
                          child: Text('No users found.',
                              style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final user = UserModel.fromDocument(results[i]);
                        final joined = DateFormat('dd MMM yyyy').format(
                          DateTime.fromMicrosecondsSinceEpoch(
                              int.tryParse(user.createdAt) ?? 0),
                        );
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: user.photoUrl.isNotEmpty
                                ? CachedNetworkImageProvider(user.photoUrl)
                                : null,
                            child: user.photoUrl.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white)
                                : null,
                          ),
                          title: Text(user.nickname,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text('Joined: $joined',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                currentUserId: currentUserId,
                                receiverId: user.id,
                                receiverName: user.nickname,
                                receiverAvatar: user.photoUrl,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
