// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:preferences/preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';

import 'settings.dart';
import 'dart:async';


const Color _kFlutterBlue = Color(0xFF003D75);


main() async {
  await PrefService.init(prefix: 'pref_');
  PrefService.setDefaultValues(
          {
            'reconnect': false,
            'secure': true,
          }
  );
  //PrefService.setString("target_bdaddr", null);
  runApp(MyApp());
}

final ThemeData kLightGalleryTheme = _buildLightTheme();
ThemeData _buildLightTheme() {
  const Color primaryColor = Color(0xFF0175c2);
  const Color secondaryColor = Color(0xFF13B9FD);
  final ColorScheme colorScheme = const ColorScheme.light().copyWith(
    primary: primaryColor,
    secondary: secondaryColor,
  );
  final ThemeData base = ThemeData(
    brightness: Brightness.light,
    accentColorBrightness: Brightness.dark,
    colorScheme: colorScheme,
    primaryColor: primaryColor,
    buttonColor: primaryColor,
    indicatorColor: Colors.white,
    toggleableActiveColor: const Color(0xFF1E88E5),
    splashColor: Colors.white24,
    splashFactory: InkRipple.splashFactory,
    accentColor: secondaryColor,
    canvasColor: Colors.white,
    scaffoldBackgroundColor: Colors.white,
    backgroundColor: Colors.white,
    errorColor: const Color(0xFFB00020),
    buttonTheme: ButtonThemeData(
      colorScheme: colorScheme,
      textTheme: ButtonTextTheme.primary,
    ),
  );
  return base.copyWith(
    textTheme: _buildTextTheme(base.textTheme),
    primaryTextTheme: _buildTextTheme(base.primaryTextTheme),
    accentTextTheme: _buildTextTheme(base.accentTextTheme),
  );
}
TextTheme _buildTextTheme(TextTheme base) {
  return base.copyWith(
    title: base.title.copyWith(
      fontFamily: 'GoogleSans',
    ),
  );
}



class MyApp extends StatelessWidget {
  // This widget is the root of your application.

  ScrollableTabsDemo m_widget;

  @override
  Widget build(BuildContext context) {

    m_widget = ScrollableTabsDemo();

    return MaterialApp(
      title: 'Settings',
      theme: kLightGalleryTheme,
      home: m_widget,
    );
  }
}


enum TabsDemoStyle {
  iconsAndText,
  iconsOnly,
  textOnly
}

class _Page {
  const _Page({ this.icon, this.text });
  final IconData icon;
  final String text;
}

const List<_Page> _allPages = <_Page>[
  _Page(icon: Icons.bluetooth, text: 'Connect'),
  _Page(icon: Icons.cloud_download, text: 'RTK'),
  _Page(icon: Icons.location_on, text: 'Location'),
  _Page(icon: Icons.satellite, text: 'Satellites'),
  _Page(icon: Icons.landscape, text: 'Map'),
  _Page(icon: Icons.view_list, text: 'NMEA'),
];

class ScrollableTabsDemo extends StatefulWidget {
  ScrollableTabsDemoState m_state;
  @override
  ScrollableTabsDemoState createState() {
    m_state = ScrollableTabsDemoState();
    return m_state;
  }
}

class ScrollableTabsDemoState extends State<ScrollableTabsDemo> with SingleTickerProviderStateMixin {

  static const method_channel = MethodChannel("com.clearevo.bluetooth_gnss/engine");
  static const event_channel = EventChannel("com.clearevo.bluetooth_gnss/engine_events");

  String _status = "Loading status...";
  String _selected_device = "Loading selected device...";

  static const double default_checklist_icon_size = 35;
  static const double default_connect_state_icon_size = 60;

  static const ICON_NOT_CONNECTED =  Icon(
    Icons.bluetooth_disabled,
    color: Colors.red,
    size: default_connect_state_icon_size,
  );

  static const FLOATING_ICON_BLUETOOTH_SETTINGS =  Icon(
    Icons.settings_bluetooth,
  );

  static const FLOATING_ICON_BLUETOOTH_CONNECT =  Icon(
    Icons.bluetooth_connected,
  );

  static const FLOATING_ICON_BLUETOOTH_CONNECTING =  Icon(
    Icons.bluetooth_connected,
  );

  static const ICON_CONNECTED =  Icon(
    Icons.bluetooth_connected,
    color: Colors.blue,
    size: default_connect_state_icon_size,
  );

  static const ICON_LOADING =  Icon(
    Icons.access_time,
    color: Colors.grey,
    size: default_connect_state_icon_size,
  );

  static const ICON_OK =  Icon(
    Icons.check_circle,
    color: Colors.lightBlueAccent,
    size: default_checklist_icon_size,
  );
  static const ICON_FAIL =  Icon(
    Icons.cancel,
    color: Colors.blueGrey,
    size: default_checklist_icon_size,
  );

  static const uninit_state = "Loading state...";

  //Map<String, String> _check_state_map =

  Map<String, Icon> _check_state_map_icon = {
    "Bluetooth On": ICON_LOADING,
    "Bluetooth Device Paired": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Bluetooth Device Selected": ICON_LOADING,
    "Mock location enabled": ICON_LOADING,
  };

  Icon _m_floating_button_icon = Icon(Icons.access_time);

  Icon _main_icon = ICON_LOADING;
  String _main_state = "Loading...";
  static String WAITING_DEV = "No data";
  bool _is_bt_connected = false;
  bool _is_bt_conn_thread_alive_likely_connecting = false;
  String _dev_time = WAITING_DEV;
  String _dev_lat = WAITING_DEV;
  String _dev_lon = WAITING_DEV;
  String _dev_alt = WAITING_DEV;
  String _dev_hdop = WAITING_DEV;
  String _gga_count = "0";
  String _rmc_count = "0";
  String _location_from_talker = WAITING_DEV;

  String _gn_n_sats_used = WAITING_DEV;
  String _gp_n_sats_used = WAITING_DEV;
  String _gl_n_sats_used = WAITING_DEV;
  String _gb_n_sats_used = WAITING_DEV;
  String _ga_n_sats_used = WAITING_DEV;
  String _gn_sat_ids = WAITING_DEV;

  int _mock_location_set_ts;
  String _mock_location_set_status = WAITING_DEV;

  List<String> users = ["ff"];

  TabController _controller;
  TabsDemoStyle _demoStyle = TabsDemoStyle.iconsAndText;
  bool _customIndicator = false;

  Timer timer;

  static String note_how_to_disable_mock_location = "NOTE: To use internal phone GPS again:\nGo to phone 'Settings' > 'Developer Options'\n > 'Mock location app'\nSet to 'No apps' and restart phone.";

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(Duration(seconds: 1), (Timer t) => check_and_update_selected_device());

    _controller = TabController(vsync: this, length: _allPages.length);

    check_and_update_selected_device();


    event_channel.receiveBroadcastStream().listen(
            (dynamic event) {

              //print("got event -----------");
              Map<dynamic, dynamic> param_map = event;

              //update params mapped to UI
              if (param_map.containsKey("GN_time")) {
                setState(() {
                  _dev_time = param_map["GN_time"];
                });
              }

              if (param_map.containsKey("GN_GGA_count")) {
                setState(() {
                  _gga_count = param_map["GN_GGA_count"].toString();
                });
              }

              if (param_map.containsKey("GN_RMC_count")) {
                setState(() {
                  _rmc_count = param_map["GN_RMC_count"].toString();
                });
              }


              if (param_map.containsKey("lat") && param_map.containsKey("lon") && param_map.containsKey("alt")) {
                setState(() {
                  try {
                    double tmp;

                    tmp = param_map["lat"];
                    _dev_lat = tmp.toStringAsFixed(7);

                    tmp = param_map["lon"];
                    _dev_lon = tmp.toStringAsFixed(7);

                    tmp = param_map["alt"];
                    _dev_alt = tmp.toStringAsFixed(2);

                    tmp = param_map["hdop"];
                    _dev_hdop = tmp.toStringAsFixed(2);

                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }

              if (param_map.containsKey('location_from_talker')) {
                try {
                  _location_from_talker = param_map['location_from_talker'];
                  switch (_location_from_talker) {
                    case 'GN':
                      _location_from_talker = 'Multi GNSS (\$$_location_from_talker)';
                      break;
                    case 'GA':
                      _location_from_talker = 'Galileo (\$$_location_from_talker)';
                      break;
                    case 'BE':
                      _location_from_talker = 'BeiDou (\$$_location_from_talker)';
                      break;
                    case 'GL':
                      _location_from_talker = 'GLONASS (\$$_location_from_talker)';
                      break;
                    case 'GP':
                      _location_from_talker = 'GPS (\$$_location_from_talker)';
                      break;
                  }
                } on Exception catch (e) {
                  print('get parsed param exception: $e');
                }
              }

              if (param_map.containsKey('mock_location_set_ts')) {
                try {
                  int mock_set_millis_ago;
                  _mock_location_set_ts = param_map['mock_location_set_ts'];
                } on Exception catch (e) {
                  print('get parsed param exception: $e');
                }
              }


              if (param_map.containsKey("GP_n_sats_used")) {
                setState(() {
                  try {
                    _gp_n_sats_used = param_map["GP_n_sats_used"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }


              if (param_map.containsKey("GL_n_sats_used")) {
                setState(() {
                  try {
                    _gl_n_sats_used = param_map["GL_n_sats_used"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }


              if (param_map.containsKey("GA_n_sats_used")) {
                setState(() {
                  try {
                    _ga_n_sats_used = param_map["GA_n_sats_used"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }


              if (param_map.containsKey("GB_n_sats_used")) {
                setState(() {
                  try {
                    _gb_n_sats_used = param_map["GB_n_sats_used"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }


              if (param_map.containsKey("GN_n_sats_used")) {
                setState(() {
                  try {
                    _gn_n_sats_used = param_map["GN_n_sats_used"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }

              if (param_map.containsKey("GN_sat_ids")) {
                setState(() {
                  try {
                    _gn_sat_ids = param_map["GN_sat_ids"].toString();
                  } on Exception catch (e) {
                    print('get parsed param exception: $e');
                  }
                });
              }


              if (false) {
                for (dynamic key in param_map.keys) {
                  dynamic val = param_map[key];
                  print("key $key val $val");
                }
              }

        },
        onError: (dynamic error) {
          print('Received error: ${error.message}');
        }
    );

  }

  void cleanup()
  {
    print('cleanup()');
    if (timer != null) {
      timer.cancel();
    }
  }

  @override
  void deactivate()
  {
    print('deactivate()');
    //cleanup();
  }

  @override
  void dispose() {
    print('dispose()');
    cleanup();

    _controller.dispose();
    super.dispose();
  }

  void changeDemoStyle(TabsDemoStyle style) {
    setState(() {
      _demoStyle = style;
    });
  }

  Decoration getIndicator() {
    if (!_customIndicator)
      return const UnderlineTabIndicator();

    switch(_demoStyle) {
      case TabsDemoStyle.iconsAndText:
        return ShapeDecoration(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
            side: BorderSide(
              color: Colors.white24,
              width: 2.0,
            ),
          ) + const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4.0)),
            side: BorderSide(
              color: Colors.transparent,
              width: 4.0,
            ),
          ),
        );

      case TabsDemoStyle.iconsOnly:
        return ShapeDecoration(
          shape: const CircleBorder(
            side: BorderSide(
              color: Colors.white24,
              width: 4.0,
            ),
          ) + const CircleBorder(
            side: BorderSide(
              color: Colors.transparent,
              width: 4.0,
            ),
          ),
        );

      case TabsDemoStyle.textOnly:
        return ShapeDecoration(
          shape: const StadiumBorder(
            side: BorderSide(
              color: Colors.white24,
              width: 2.0,
            ),
          ) + const StadiumBorder(
            side: BorderSide(
              color: Colors.transparent,
              width: 4.0,
            ),
          ),
        );
    }
    return null;
  }

  Scaffold _scaffold;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Theme.of(context).accentColor;

    _scaffold = Scaffold(

      appBar: AppBar(
        title: const Text('Bluetooth GNSS'),
        actions: <Widget>[

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              check_and_update_selected_device(true, false).then(
                      (sw) {
                        if (_is_bt_connected || _is_bt_conn_thread_alive_likely_connecting) {
                          toast("Please Disconnect first - cannot change settings during live connection...");
                          return;
                        } else if (sw == null || sw.m_bdaddr_to_name_map == null) {
                          toast("Please turn ON Bluetooth and pair your Bluetooth Device first...");
                          return;
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) {
                              dynamic bdmap = sw.m_bdaddr_to_name_map;
                              print("sw.bdaddr_to_name_map: $bdmap");
                              return settings_widget(bdmap);
                            }
                            ),
                          );
                        }
                      }
              );
            },
          ),
          // overflow menu
          PopupMenuButton(
                  itemBuilder: (_) => <PopupMenuItem<String>>[
                    new PopupMenuItem<String>(
                            child: const Text('Disconnect'),
                            value: 'disconnect',
                    ),
                    new PopupMenuItem<String>(
                            child: const Text('About'), value: 'about'),
                  ],
                  onSelected: menu_selected,
          ),
        ],
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          indicator: getIndicator(),
          tabs: _allPages.map<Tab>((_Page page) {
            assert(_demoStyle != null);
            switch (_demoStyle) {
              case TabsDemoStyle.iconsAndText:
                return Tab(text: page.text, icon: Icon(page.icon));
              case TabsDemoStyle.iconsOnly:
                return Tab(icon: Icon(page.icon));
              case TabsDemoStyle.textOnly:
                return Tab(text: page.text);
            }
            return null;
          }).toList(),
        ),
      ),
    floatingActionButton: Visibility(
      visible: !_is_bt_connected,
            child: FloatingActionButton(
              onPressed: connect,
              tooltip: 'Connect',
              child: _m_floating_button_icon,
            )
    ), // This trailing comma makes auto-formatting nicer for build methods.
      body: new SafeArea(child: TabBarView(
        controller: _controller,
        children: _allPages.map<Widget>((_Page page) {
          String pname = page.text;
          print ("page: $pname");

          switch (pname) {

            case "Connect":
              List<Widget> rows = null;
              if (_is_bt_connected) {

                rows = <Widget>[
                  Card(
                    child: Container(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Connected',
                                  style: Theme.of(context).textTheme.headline.copyWith(
                                          fontFamily: 'GoogleSans',
                                          color: Colors.blueGrey
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(5.0),
                                ),
                                ICON_CONNECTED
                                ,
                                Padding(
                                  padding: const EdgeInsets.all(5.0),
                                ),
                                Text(
                                        '$_selected_device'
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(5.0),
                                ),
                                Text(
                                        "NOTE: We are now the 'Mock location app' and broadcasting below location to all other apps.\n"+note_how_to_disable_mock_location,
                                        style: Theme.of(context).textTheme.caption
                                ),
                              ],
                            )
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),                  
                  Card(
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: <Widget>[
                          Text(
                            'GNSS Device read stats',
                            style: Theme.of(context).textTheme.subhead.copyWith(
                                    fontFamily: 'GoogleSans',
                                    color: Colors.blueGrey
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'GNSS Time:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_dev_time',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'Lat, Lon:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_dev_lat, $_dev_lon',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'Altitude:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_dev_alt',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'HDOP:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_dev_hdop',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'Location updated to OS:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_mock_location_set_status',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'NMEA Talker used:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_location_from_talker',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'GN Sat IDs:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gn_sat_ids',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'N Sats used total:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gn_n_sats_used',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'N Galileo used:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_ga_n_sats_used',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'N GPS used:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gp_n_sats_used',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'N GLONASS used:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gl_n_sats_used',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'N BeiDou used:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gb_n_sats_used',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'Total GGA Count:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_gga_count',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                      'Total RMC Count:',
                                      style: Theme.of(context).textTheme.body2
                              ),
                              Text(
                                      '$_rmc_count',
                                      style: Theme.of(context).textTheme.body1
                              ),
                            ],
                          ),


                        ],
                      ),

                    ),
                  ),
                  

                ];

              } else if (_is_bt_connected == false && _is_bt_conn_thread_alive_likely_connecting) {

                rows = <Widget>[
                  Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                          [
                            ICON_LOADING,
                          ]
                  ),
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                  ),
                  Text(
                    '$_status',
                    style: Theme.of(context).textTheme.headline,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                  Text(
                    'Selected device:',
                    style: Theme.of(context).textTheme.caption,
                  ),
                  Text(
                          '$_selected_device'
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                ];

              } else {

                rows = <Widget>[
                  Text(
                    'Pre-connect checklist',
                    style: Theme.of(context).textTheme.headline.copyWith(
                      fontFamily: 'GoogleSans',
                      color: Colors.blueGrey
                    ),
                    //style: Theme.of(context).textTheme.headline,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                  ),
                ];

                List<Widget> checklist = [];
                for (String key in _check_state_map_icon.keys) {
                  Row row = Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children:
                      [
                        _check_state_map_icon[key],
                        new Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  key,
                                  style: Theme.of(context).textTheme.body1,
                                )
                        ),
                      ]
                  );
                  checklist.add(row);
                }

                rows.add(
                  new Card(
                          child: new Container(
                            padding: const EdgeInsets.all(10.0),
                            child: new Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: checklist,
                            ),
                          )
                  )
                );

                List<Widget> bottom_widgets = [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                  ),
                  new Card(
                    child: new Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(15.0),
                        ),
                        Text(
                          'Next step',
                          style:  Theme.of(context).textTheme.headline.copyWith(
                            fontFamily: 'GoogleSans',
                            color: Colors.blueGrey,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                        ),
                        new Container(
                          padding: const EdgeInsets.all(10.0),

                          child: Text(
                            '$_status',
                            style: Theme.of(context).textTheme.subhead,
                          ),
                        ),
                      ],
                    )
                  )

                ];
                rows.addAll(bottom_widgets);
              }

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: new Container(
                          child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: rows,
                  )),
                )
              );
              break;


              /*
            case "Location":
              print("build location");
              return  SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columns: [
                    DataColumn(
                      label: Text("System"),
                      numeric: false,
                      tooltip: "The GNSS System used",
                    ),
                    DataColumn(
                      label: Text("System"),
                      numeric: false,
                      tooltip: "The GNSS System used",
                    ),
                  ],
                  rows: users
                          .map(
                            (user) => DataRow(

                            cells: [
                              DataCell(
                                Text(user),

                              ),
                              DataCell(
                                Text(user),
                              ),
                            ]),
                  )
                          .toList(),
                ),
              );
              break;
              */
          }
          return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: new Container(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "<UNDER DEVELOPMENT/>\n\nSorry, dev not done yet - please check again after next update...",
                                  style:  Theme.of(context).textTheme.headline.copyWith(
                                    fontFamily: 'GoogleSans',
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ],
                            )),
                  )
          );

        }).toList(),
      ),
    ));

    return _scaffold;
  }


  /////////////functions

  void menu_selected(String menu) async {
    print('menu_selected: $menu');
    switch (menu) {
      case "disconnect":
        await disconnect();
        break;
      case "about":
        //TODO show dialog
        break;
    }
  }

  void clear_disp_text() {
    _selected_device = "";
    _status = "";
  }

  //return settings_widget that can be used to get selected bdaddr
  Future<settings_widget_state> check_and_update_selected_device([bool user_pressed_settings_take_action_and_ret_sw=false, bool user_pressed_connect_take_action_and_ret_sw=false]) async {

    print('check_and_update_selected_device0');
    _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_SETTINGS;

    try {
      _is_bt_connected = await method_channel.invokeMethod('is_bt_connected');

      if (_is_bt_connected) {
        _status = "Connected";
        _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECT;

        try {
          int mock_set_millis_ago;
          DateTime now = DateTime.now();
          int nowts = now.millisecondsSinceEpoch;
          _mock_location_set_status = "";
          mock_set_millis_ago = nowts - _mock_location_set_ts;
          //print("mock_location_set_ts $mock_set_ts, nowts $nowts");

          double secs_ago = mock_set_millis_ago / 1000.0;

          if (_mock_location_set_ts == 0) {
            setState(() {
              _mock_location_set_status = "Never";
            });
          } else {
            setState(() {
              _mock_location_set_status =
                      secs_ago.toStringAsFixed(3) + " Seconds ago";
            });
          }

        } on Exception catch (e) {
          print('get parsed param exception: $e');
        }

        return null;
      }

    } on PlatformException catch (e) {
      toast("WARNING: check _is_bt_connected failed: $e");
      _is_bt_connected = false;
    }

    try {
      _is_bt_conn_thread_alive_likely_connecting = await method_channel.invokeMethod('is_conn_thread_alive');

      if (_is_bt_conn_thread_alive_likely_connecting) {
          _status = "Connecting...";
        return null;
      }
      
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
      _is_bt_conn_thread_alive_likely_connecting = false;
    }
    print('check_and_update_selected_device1');

    _check_state_map_icon.clear();
    _main_icon = ICON_FAIL;
    _main_state = "Not ready";

    print('check_and_update_selected_device2');

    if (! (await is_bluetooth_on())) {
      String msg = "Bluetooth is OFF - Please turn ON Bluetooth...";
      setState(() {
        _check_state_map_icon["Bluetooth is OFF"] = ICON_FAIL;
        _status = msg;

      });
      print('check_and_update_selected_device4');
      
      if (user_pressed_connect_take_action_and_ret_sw || user_pressed_settings_take_action_and_ret_sw) {
        bool open_act_ret = false;
        try {
          open_act_ret = await method_channel.invokeMethod('open_phone_blueooth_settings');
          toast("Please turn ON Bluetooth...");
        } on PlatformException catch (e) {
          print("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }      
      return null;
    }
    
    _check_state_map_icon["Bluetooth powered ON"] = ICON_OK;
    print('check_and_update_selected_device5');

    Map<dynamic, dynamic> bd_map = await get_bd_map();
    if (bd_map.length == 0) {
      String msg = "Please pair your Bluetooth GPS/GNSS Receiver in phone Settings > Bluetooth first.\n\nClick button below to go there...";
      setState(() {
        _check_state_map_icon["No paired Bluetooth devices"] = ICON_FAIL;
        _status = msg;
        _selected_device = "No paired Bluetooth devices yet...";
      });
      print('check_and_update_selected_device6');
      if (user_pressed_connect_take_action_and_ret_sw || user_pressed_settings_take_action_and_ret_sw) {
        bool open_act_ret = false;
        try {
          open_act_ret = await method_channel.invokeMethod('open_phone_blueooth_settings');
          toast("Please pair your Bluetooth GPS/GNSS Device...");
        } on PlatformException catch (e) {
          print("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }
    print('check_and_update_selected_device7');
    _check_state_map_icon["Found paired Bluetooth devices"] = ICON_OK;

    print('check_and_update_selected_device8');
    settings_widget_state sw = settings_widget_state(bd_map);
    if (user_pressed_settings_take_action_and_ret_sw) {
      return sw;
    }

    print('check_and_update_selected_device9');

    if (sw.get_selected_bdaddr() == null) {
      String msg = "Please select your Bluetooth GPS/GNSS Receiver in Settings (the gear icon on top right)";
      /*Fluttertoast.showToast(
          msg: msg
      );*/
      setState(() {
        _check_state_map_icon["Device not selected in gear icon"] = ICON_FAIL;
        _selected_device = sw.get_selected_bd_summary();
        _status = msg;
      });
      print('check_and_update_selected_device10');

      _main_icon = ICON_NOT_CONNECTED;
      _main_state = "Not connected";

      return null;
    }
    _check_state_map_icon["Target device selected"] = ICON_OK;

    print('check_and_update_selected_device11');

    if (! (await is_location_enabled())) {
      String msg = "Location needs to be on and set to 'High Accuracy Mode' - Please go to phone Settings > Location to change this...";
      setState(() {
        _check_state_map_icon["Location must be ON and 'High Accuracy'"] = ICON_FAIL;
        _status = msg;
      });

      print('pre calling open_phone_location_settings() user_pressed_connect_take_action_and_ret_sw $user_pressed_connect_take_action_and_ret_sw');

      if (user_pressed_connect_take_action_and_ret_sw) {
        bool open_act_ret = false;
        try {
          print('calling open_phone_location_settings()');
          open_act_ret = await method_channel.invokeMethod('open_phone_location_settings');
          toast("Please set Location ON and 'High Accuracy Mode'...");
        } on PlatformException catch (e) {
          print("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      print('check_and_update_selected_device12');
      return null;
    }
    print('check_and_update_selected_device13');
    _check_state_map_icon["Location is on and 'High Accuracy'"] = ICON_OK;


    if (! (await is_mock_location_enabled())) {
      String msg = "Please go to phone Settings > Developer Options > Mock Location Provider and set 'Mock Location app' to 'Bluetooth GNSS'...";
      setState(() {
        _check_state_map_icon["'Mock Location app' not 'Bluetooth GNSS'\n"] = ICON_FAIL;
        _status = msg;
      });
      print('check_and_update_selected_device14');
      if (user_pressed_connect_take_action_and_ret_sw) {
        bool open_act_ret = false;
        try {
          open_act_ret = await method_channel.invokeMethod('open_phone_developer_settings');
          toast("Please set 'Mock Locaiton app' to 'Blueooth GNSS'..");
        } on PlatformException catch (e) {
          print("Please open phone Settings and change first (can't redirect screen: $e)");
        }
      }
      return null;
    }
    print('check_and_update_selected_device15');
    _check_state_map_icon["'Mock Location app' is 'Bluetooth GNSS'\n"+note_how_to_disable_mock_location] = ICON_OK;
    _main_icon = ICON_OK;


    if (_is_bt_connected == false && _is_bt_conn_thread_alive_likely_connecting) {
      setState(() {
        _main_icon = ICON_LOADING;
        _main_state = "Connecting...";
          _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECTING;
      });
      print('check_and_update_selected_device16');
    } else {
      //ok - ready to connect
      setState(() {
        _selected_device = sw.get_selected_bd_summary();
        _status = "Please press the button below to connect...";
          _m_floating_button_icon = FLOATING_ICON_BLUETOOTH_CONNECT;
      });
      print('check_and_update_selected_device17');
    }

    //setState((){});
    print('check_and_update_selected_device18');

    return sw;
  }

  void toast(String msg)
  {
    /*
    */
    if (true) {
      Fluttertoast.showToast(
        msg: msg,
      );
    } else {
      final snackBar = SnackBar(content: Text(msg));

      Scaffold.of(context).showSnackBar(snackBar);
    }

  }

  Future<void> disconnect() async
  {
    try {
      await method_channel.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      toast("WARNING: disconnect failed: $e");
    }
  }

  Future<void> connect() async {

    if (_is_bt_connected) {
      toast("Already connected...");
      return;
    }

    if (_is_bt_conn_thread_alive_likely_connecting) {
      toast("Connecting, please wait...");
      return;
    }

    settings_widget_state sw = await check_and_update_selected_device(false, true);
    if (sw == null) {
      //toast("Please see Pre-connect checklist...");
      return;
    }

    bool connecting = false;
    try {
      connecting = await method_channel.invokeMethod('is_conn_thread_alive');
    } on PlatformException catch (e) {
      toast("WARNING: check _is_connecting failed: $e");
    }

    if (connecting) {
      toast("Connecting - please wait...");
      return;
    }


    String bdaddr = sw.get_selected_bdaddr();
    if (bdaddr == null) {
      toast(
        "Please select your Bluetooth GPS/GNSS Receiver device...",
      );

      Map<dynamic, dynamic> bdaddr_to_name_map = await get_bd_map();
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) {
              return settings_widget(bdaddr_to_name_map);
            }
        ),
      );
      return;
    }

    String status = "unknown";
    try {
      final int ret = await method_channel.invokeMethod('connect',
              {
                "bdaddr": bdaddr,
                'secure': PrefService.getBool('secure') ?? true,
                'reconnect' :PrefService.getBool('reconnect') ?? false,
              }
      );
      if (ret == 0) {
        status = "Starting connection...";
      } else {
        status = "Failed to connect...";
        setState(() {
          _main_icon = ICON_NOT_CONNECTED;
          _main_state = "Not connected";
        });
      }

    } on PlatformException catch (e) {
      status = "Failed to start connection: '${e.message}'.";
      print(status);
    }

    setState(() {
      _status = status;
    });
  }

  Future<Map<dynamic, dynamic>> get_bd_map() async {
    Map<dynamic, dynamic> ret = null;
    try {
      ret = await method_channel.invokeMethod<Map<dynamic, dynamic>>('get_bd_map');
      print("got bt_map: $ret");
    } on PlatformException catch (e) {
      String status = "get_bd_map exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }

  Future<bool> is_bluetooth_on() async {
    bool ret = false;
    try {
      ret = await method_channel.invokeMethod<bool>('is_bluetooth_on');
    } on PlatformException catch (e) {
      String status = "is_bluetooth_on exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }

  Future<bool> is_location_enabled() async {
    bool ret = false;
    try {
      print("is_location_enabled try0");
      ret = await method_channel.invokeMethod<bool>('is_location_enabled');
      print("is_location_enabled got ret: $ret");
    } on PlatformException catch (e) {
      String status = "is_location_enabled exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }


  Future<bool> is_mock_location_enabled() async {
    bool ret = false;
    try {
      print("is_mock_location_enabled try0");
      ret = await method_channel.invokeMethod<bool>('is_mock_location_enabled');
      print("is_mock_location_enabled got ret $ret");
    } on PlatformException catch (e) {
      String status = "is_mock_location_enabled exception: '${e.message}'.";
      print(status);
    }
    return ret;
  }

}