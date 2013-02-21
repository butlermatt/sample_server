library SampleServer;

import 'dart:io';
import 'dart:async';

class RequestRouter {
  Set<Route> _routes;
  Route _default;
  
  RequestRouter() {
    _routes = new Set<Route>();
  }
  
  void addRoute(Route rt) => _routes.add(rt);
  
  void set defaultRoute(Route rt) {
    _default = rt;
  } 
  
  void handleRequest(HttpRequest req) {
    if(_routes.isEmpty) {
      // Handle this more gracefully.
      if(_default == null) {
        req.response.close();
      } else {
        _default.controller.add(req);
      }
      return;
    } 
    
    var rt = _routes.firstMatching((route) => route.matcher(req),
        orElse: () => _default);
    
    if(rt != null) {
      rt.controller.add(req);
    }
  }
}

typedef bool RouteMatcher(HttpRequest req);

class Route extends Stream<HttpRequest> {
  StreamController<HttpRequest> controller;
  RouteMatcher matcher;
  
  Route(this.matcher) {
    controller = new StreamController<HttpRequest>();
  }
  
  StreamSubscription<HttpRequest> listen(void onData(HttpRequest request), 
      {void onError(AsyncError error), 
      void onDone(),
      bool unsubscribeOnError}) {
    
    return controller.stream.listen(onData, 
        onError: onError,
        onDone: onDone, 
        unsubscribeOnError: unsubscribeOnError);
  }
  
}

class SampleServer {
  
  void run() {
    HttpServer.bind('127.0.0.1', 8080).then((HttpServer server) {
      server.listen((HttpRequest req) {
        print('Path: ${req.uri.path}');
        print('Method: ${req.method}');
        
        var router = new RequestRouter();
        
        var rt = new Route((req) => req.uri.path.startsWith('/users/'));
        rt.listen((HttpRequest req) {
          print('Inside /users/ request');
          
          var myRouter = new RequestRouter();
          var smallRoute = 
              new Route((req) => req.uri.path.startsWith('/users/list/'));
          smallRoute.listen((HttpRequest myReq) {
            print('Inside /users/list/ request');
            
            var resp = req.response;
            resp.addString('Got Users/List!');
            resp.close();
          });
          myRouter.addRoute(smallRoute);
          
          smallRoute = 
              new Route((req) => req.uri.path.startsWith('/users/show/'));
          
          smallRoute.listen((HttpRequest req) {
            print('Inside /users/show/ request');
            
            var resp = req.response;
            resp.addString('Got Users/Show!');
            resp.close();
          });
          
          myRouter.addRoute(smallRoute);
          
          smallRoute = new Route((req) => true);
          smallRoute.listen((req) {
            print('Inside default for /users/ router');
            
            var resp = req.response;
            resp.addString('Got Users!');
            resp.close();
          });
          
          myRouter.defaultRoute = smallRoute;
          
          myRouter.handleRequest(req);
         
        });
        
        router.addRoute(rt);
        
        rt = new Route((req) => true);
        rt.listen((HttpRequest req) {
          print('Inside default route');
          
          req.response.addString('default route');
          req.response.close();
        });
        
        router.defaultRoute = rt;
        
        router.handleRequest(req);
      });
    });
  }
}

main() {
  var server = new SampleServer();
  server.run();
}
