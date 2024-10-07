import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert'; // For JSON encoding/decoding

void main() => runApp(ChatApp());

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  ChatAppState createState() => ChatAppState();
}

class ChatAppState extends State<ChatApp> {
  WebSocketChannel? _webSocket;
  List<Map<String, dynamic>> _messages = [];
  TextEditingController _controller = TextEditingController();
  bool _isConnected = false;
  String? _connectionError;
  List<String> _users = [];
  String? _clientId;
  String _selectedUser = 'all'; // 'all' means general chat

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _webSocket = IOWebSocketChannel.connect('ws://192.168.0.100:3000');
      setState(() {
        _isConnected = true;
      });
      _webSocket!.stream.listen((data) {
        var message = jsonDecode(data);
        if (message['type'] == 'init') {
          // Receive the assigned client ID
          setState(() {
            _clientId = message['clientId'];
          });
          print('Menga berilgan ID: $_clientId');
        } else if (message['type'] == 'user_list') {
          setState(() {
            _users = List<String>.from(message['users']);
            _users.remove(_clientId); // Remove self from the list
          });
        } else if (message['type'] == 'message') {
          setState(() {
            _messages.add(message);
          });
        }
      }, onDone: () {
        setState(() {
          _isConnected = false;
        });
      }, onError: (error) {
        print('WebSocket xatosi: $error');
        setState(() {
          _isConnected = false;
          _connectionError = 'WebSocket xatosi: $error';
        });
      });
    } catch (e) {
      print('WebSocketga ulanishda xato: $e');
      setState(() {
        _isConnected = false;
        _connectionError = 'Ulanishda xato: $e';
      });
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty && _webSocket != null) {
      var message = {
        'type': 'message',
        'text': _controller.text,
        'to': _selectedUser,
      };
      _webSocket!.sink.add(jsonEncode(message));
      _controller.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('WebSocket ulanishi mavjud emas.')),
      );
    }
  }

  @override
  void dispose() {
    _webSocket?.sink.close();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildMessageItem(Map<String, dynamic> message) {
    bool isSentByMe = message['from'] == _clientId;
    return Container(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: isSentByMe ? Colors.green[200] : Colors.blue[200],
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: EdgeInsets.all(10.0),
        child: Text(
          '${message['from']}: ${message['text']}',
          style: TextStyle(fontSize: 16.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Ilovasi',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Chat Ilovasi'),
          actions: [
            Icon(
              _isConnected ? Icons.link : Icons.link_off,
              color: Colors.white,
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.blue,
                ),
                child: Text('Foydalanuvchilar'),
              ),
              ListTile(
                title: Text('Umumiy Chat'),
                selected: _selectedUser == 'all',
                onTap: () {
                  setState(() {
                    _selectedUser = 'all';
                  });
                  Navigator.pop(context);
                },
              ),
              for (var userId in _users)
                ListTile(
                  title: Text(userId),
                  selected: _selectedUser == userId,
                  onTap: () {
                    setState(() {
                      _selectedUser = userId;
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_connectionError != null)
              Container(
                color: Colors.redAccent,
                padding: EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        _connectionError!,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _connectionError = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            if (!_isConnected && _connectionError == null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'WebSocket ulanishi o\'rnatilmoqda...',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  var message = _messages[index];

                  // Filter messages based on the selected user or general chat
                  if (_selectedUser == 'all' && message['to'] != 'all') {
                    return SizedBox
                        .shrink(); // Do not display private messages in general chat
                  } else if (_selectedUser != 'all') {
                    if (message['to'] == 'all') {
                      return SizedBox
                          .shrink(); // Do not display general messages in private chat
                    } else if (message['from'] != _selectedUser &&
                        message['from'] != _clientId) {
                      return SizedBox
                          .shrink(); // Do not display unrelated private messages
                    }
                  }

                  return _buildMessageItem(message);
                },
              ),
            ),
            Divider(height: 1.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(hintText: 'Xabar yozing...'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: _isConnected ? _sendMessage : null,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
