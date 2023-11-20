import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ignore: deprecated_member_use
          accentColor: MaterialStateColor.resolveWith((states) => Color(0xfff85c70)),
          colorScheme: ColorScheme.light(
              primary: MaterialStateColor.resolveWith((states) => Color(0xfff85c70))
          )
      ),
      title: 'Ramco Systems',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>{

  bool _isInternet = true; //Internet
  bool isLoading = false; //Loading
  String defaultUrl="https://192.168.1.9:8050/";
  double progress = 0;
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  PullToRefreshController? pullToRefreshController;
  PullToRefreshOptions pullToRefreshOptions = PullToRefreshOptions(
    color: Color(0xfff85c70),
  );

  //Show Exit Alert Dialog
  showalertdialog() {
    setState(() {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10.0))),
            title: Text('Are you want to Exit?',style: TextStyle(fontSize: 17.0,fontWeight: FontWeight.normal),),
            actions: <Widget>
            [
              TextButton(
                  onPressed: () => exit(0),
                  child: Text('YES')),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('NO'))
            ],
          ));
    });
  }

  //Check Internet Available
  checkInternet() async {
    try {
      final response = await InternetAddress.lookup('google.com'); // google
      if (response.isNotEmpty && response[0].rawAddress.isNotEmpty) {
        _isInternet = true; // internet
        setState(() {});
      }

    } on SocketException catch (_) {
      _isInternet = false; // no internet
      setState(() {});
    }
  }

  @override
  void initState() {
    checkInternet();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Color(0xfff85c70)
    ));

    pullToRefreshController = kIsWeb ||
        ![TargetPlatform.iOS, TargetPlatform.android]
            .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
      options: pullToRefreshOptions,
      onRefresh: () async {
        if (defaultTargetPlatform == TargetPlatform.android) {
          webViewController?.reload();
        } else if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          webViewController?.loadUrl(
              urlRequest:
              URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );

    super.initState();
  }

  Future<String> loadCertificate() async {
    return await rootBundle.loadString('assets/localhost.crt');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        if(await webViewController!.canGoBack()){
          webViewController!.goBack();
          return false;
        }else{
          showalertdialog();
          return true;
        }
      },
      child: Scaffold(
        body: _isInternet ? SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                key: webViewKey,
                initialUrlRequest: URLRequest(url: Uri.parse(defaultUrl)),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                      supportZoom: false, // WebView support for zoom
                      useOnDownloadStart: true, // Use `onDownloadStart` event to handle downloads
                      useShouldOverrideUrlLoading: true
                  ),
                ),
                pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) async {
                  webViewController = controller;
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  var uri = navigationAction.request.url;
                  if (uri!.scheme == 'whatsapp') {
                    final Uri whatsAppURL = uri;
                    launchUrl(whatsAppURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.scheme == 'fb') {
                    final Uri fbURL = uri;
                    launchUrl(fbURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.scheme == 'twitter') {
                    final Uri twitterURL = uri;
                    launchUrl(twitterURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.scheme == "tel") {
                    String phoneNumber = uri.path.replaceAll("/", "");
                    final Uri telURL = Uri.parse("tel:$phoneNumber");
                    launchUrl(telURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.scheme == "mailto") {
                    String url = uri.path;
                    final Uri mailURL = Uri.parse("mailto:$url");
                    launchUrl(mailURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else if (uri.scheme == "intent") {
                    String url = uri.path;
                    final Uri mailURL = Uri.parse(url);
                    launchUrl(mailURL);
                    return NavigationActionPolicy.CANCEL;
                  }
                  else {
                    return NavigationActionPolicy.ALLOW;
                  }
                },
                // onLoadStart: (controller, url) async {
                //   pullToRefreshController?.beginRefreshing();
                // },
                onLoadStop: (controller, url) async {
                  pullToRefreshController?.endRefreshing();
                },
                onLoadError: (InAppWebViewController? controller, Uri? url, int code, String message) {
                  checkInternet();
                },
                onLoadHttpError: (InAppWebViewController? controller, Uri? url, int statusCode, String description) {
                  checkInternet();
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    pullToRefreshController?.endRefreshing();
                  }
                  setState(() {
                    this.progress = progress / 100;
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print(consoleMessage);
                },
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  String certificate = await loadCertificate();
                  print('Certificate Chain: ${controller.getCertificate().toString()}');
                  print("URL : "+controller.getUrl().toString());
                  return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED);
                },
              ),
              progress < 1.0
                  ? LinearProgressIndicator(value: progress, color: Color(0xfffb4159))
                  : Container(),
            ],
          ),
        ) : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(top: 30.0),),
            Icon(Icons.wifi_off_sharp,color: Color(0xfff85c70),size:100.0),
            Padding(padding: EdgeInsets.only(bottom: 30.0),),
            Text(
              'Oops! you don\'t have Internet Connection',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.normal, fontSize:18, color: Color(0xfff85c70)),
            ),
            Padding(padding: EdgeInsets.only(bottom: 30.0),),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              //mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                TextButton(
                  onPressed: ()
                  {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => HomePage()));
                  },
                  child: Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xfff85c70)),),
                ),
                Padding(padding: EdgeInsets.only(right: 30.0),),
                TextButton(
                  onPressed: ()
                  {
                    showalertdialog();
                  },
                  child: Text('EXIT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xfff85c70)),),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}