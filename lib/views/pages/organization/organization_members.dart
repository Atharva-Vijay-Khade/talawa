//flutter imported packages
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

//pages are imported here
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:talawa/controllers/auth_controller.dart';
import 'package:talawa/services/Queries.dart';
import 'package:talawa/services/preferences.dart';
import 'package:talawa/utils/GQLClient.dart';
import 'package:talawa/utils/globals.dart';
import 'package:talawa/utils/uidata.dart';
import 'dart:math' as math;

class OrganizationMembers extends StatefulWidget {
  @override
  _OrganizationMembersState createState() => _OrganizationMembersState();
}

class _OrganizationMembersState extends State<OrganizationMembers>
    with SingleTickerProviderStateMixin {
  Preferences _preferences = Preferences();
  AnimationController _controller;
  GraphQLConfiguration graphQLConfiguration = GraphQLConfiguration();
  AuthController _authController = AuthController();
  List membersList = [];
  List adminsList = [];
  List selectedMembers = List();
  FToast fToast;
  bool forward = false;
  String userId;
  Queries _query = Queries();
  // Todo: to be replaced with creator's userId
  String creatorId;

  //giving initial states to every variable
  @override
  void initState() {
    super.initState();
    fToast = FToast();
    fToast.init(context);
    _controller = new AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    viewMembers();
  }

  //method to show the members of the organization
  Future viewMembers() async {
    final String orgId = await _preferences.getCurrentOrgId();
    userId = await _preferences.getUserId();
    GraphQLClient _client = graphQLConfiguration.authClient();

    QueryResult result = await _client
        .query(QueryOptions(documentNode: gql(_query.fetchOrgById(orgId))));
    if (result.hasException) {
      print(result.exception);
      //showError(result.exception.toString());
    } else if (!result.hasException) {
      result.data['organizations'][0]['admins']
          .forEach((admin) => adminsList.add(admin['_id']));
      setState(() {
        creatorId = result.data['organizations'][0]['creator']['_id'];
        membersList = result.data['organizations'][0]['members'];
      });
      if (membersList.length == 1) {
        _exceptionToast('No More members available');
      }
    }
  }

  //method called when a member has to be removed by the admin
  Future removeMembers() async {
    GraphQLClient _client = graphQLConfiguration.authClient();
    final String orgId = await _preferences.getCurrentOrgId();

    QueryResult result = await _client.query(QueryOptions(
        documentNode: gql(_query.removeMember(orgId, selectedMembers))));
    if (result.hasException &&
        result.exception.toString().substring(16) == accessTokenException) {
      _authController.getNewToken();
      return removeMembers();
    } else if (result.hasException &&
        result.exception.toString().substring(16) != accessTokenException) {
      print(result.exception.toString().substring(16));
    } else if (!result.hasException) {
      print(result.data);
      viewMembers();
    }
  }

  Future addAdmin() async {
    if (!adminsList.contains(selectedMembers[0])) {
      GraphQLClient _client = graphQLConfiguration.authClient();
      final String orgId = await _preferences.getCurrentOrgId();
      QueryResult result = await _client.query(QueryOptions(
          documentNode: gql(_query.addAdmin(orgId, selectedMembers[0]))));
      if (result.hasException &&
          result.exception.toString().substring(16) == accessTokenException) {
        _authController.getNewToken();
        return addAdmin();
      } else if (result.hasException &&
          result.exception.toString().substring(16) != accessTokenException) {
        print(result.exception.toString().substring(16));
      } else if (!result.hasException) {
        print(result.data);
        viewMembers();
      }
    } else {
      _exceptionToast('Already an admin');
    }
  }

  //add or remove selected members from list
  void _onMemberSelected(bool selected, String memberId) {
    if (selected == true) {
      print('userId: $userId creatorId: $creatorId memberId: $memberId');
      if (!adminsList.contains(memberId)) {
        setState(() {
          selectedMembers.add('"$memberId"');
        });
      } else {
        _exceptionToast('Can\'t select admins');
      }
      print(selectedMembers);
    } else {
      setState(() {
        selectedMembers.remove('"$memberId"');
      });
      print(selectedMembers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Members',
            style: TextStyle(color: Colors.white)),
      ),
      body: membersList.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: membersList.length,
              itemBuilder: (context, index) {
                final members = membersList[index];
                String mId = members['_id'];
                String name = members['firstName'] + ' ' + members['lastName'];
                return CheckboxListTile(
                  secondary: members['image'] != null
                      ? CircleAvatar(
                          radius: 30,
                          backgroundImage: NetworkImage(
                              Provider.of<GraphQLConfiguration>(context)
                                      .displayImgRoute +
                                  members['image']))
                      : CircleAvatar(
                          radius: 30.0,
                          backgroundColor: Colors.white,
                          child: Text(
                              members['firstName']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase() +
                                  members['lastName']
                                      .toString()
                                      .substring(0, 1)
                                      .toUpperCase(),
                              style: TextStyle(
                                color: UIData.primaryColor,
                                fontSize: 22,
                              )),
                        ),
                  title: Text(name),
                  subtitle: Text(adminsList.contains(mId) ? 'Admin' : ''),
                  value: selectedMembers.contains('"$mId"'),
                  onChanged: (bool value) {
                    _onMemberSelected(value, members['_id'].toString());
                  },
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return Divider();
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(2, (int index) {
          Widget child = Container(
            /*height: 70.0,
            width: 56.0,*/
            margin: EdgeInsets.only(bottom: 15),
            alignment: FractionalOffset.bottomRight,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Interval(0.0, 1.0 - index, curve: Curves.easeOut),
              ),
              child: FloatingActionButton.extended(
                heroTag: null,
                backgroundColor: UIData.secondaryColor,
                tooltip: index == 0 ? "Delete" : "Admin",
                icon: Icon(
                    index == 0 ? Icons.delete : Icons.admin_panel_settings,
                    color: Colors.white),
                label: Text(index == 0 ? "Delete" : "Admin"),
                onPressed: () {
                  if (index == 0) {
                    removeMemberDialog();
                  } else if (index == 1) {
                    if (selectedMembers.length == 1) {
                      addAdminDialog();
                    } else {
                      _exceptionToast('You can make one admin at a time');
                    }
                  }
                },
              ),
            ),
          );
          return child;
        }).toList()
          ..add(
            FloatingActionButton(
              heroTag: null,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget child) {
                  return Transform(
                    transform:
                        Matrix4.rotationZ(_controller.value * 1 * math.pi),
                    alignment: FractionalOffset.center,
                    child: Icon(Icons.expand_more),
                  );
                },
              ),
              onPressed: () {
                setState(() {
                  forward = !forward;
                });
                if (_controller.isDismissed) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            ),
          ),
      ),
    );
  }

  //dialog to confirm if the admin really wants to remove the member or not
  void removeMemberDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Confirmation"),
            content:
                Text("Are you sure you want to remove selected member(s)?"),
            actions: [
              FlatButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text("Yes"),
                onPressed: () async {
                  removeMembers();
                },
              )
            ],
          );
        });
  }

  void addAdminDialog() {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Confirmation"),
            content:
                Text("Are you sure you want to remove selected member(s)?"),
            actions: [
              FlatButton(
                child: Text("Close"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                child: Text("Yes"),
                onPressed: () async {
                  addAdmin();
                },
              )
            ],
          );
        });
  }

  _exceptionToast(String msg) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: Colors.red,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg),
        ],
      ),
    );

    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: Duration(seconds: 3),
    );
  }
}
