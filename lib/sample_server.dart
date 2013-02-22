library SampleServer;

import 'dart:io';
import 'dart:async';

class RequestRouter {
  Set<Route> _routes;
  Route _default;
  
  RequestRouter() {
    _routes = new Set<Route>();
    _default = new Route((_) => true);
  }
  
  void addRoute(Route rt) => _routes.add(rt);
  
  Route add(RouteMatcher rtMatch) {
    if(rtMatch == null) {
      throw new ArgumentError('RouteMatcher cannot be null');
    }
    var route = new Route(rtMatch);
    _routes.add(route);
    return route;
  }
  
  Route get defaultRoute => _default;
  
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
  RequestRouter router;
  
  SampleServer() {
    router = new RequestRouter();
  }
  
  void run() {
    
    HttpServer.bind('127.0.0.1', 8080).then((HttpServer server) {
      server.listen((HttpRequest req) {
        print('Path: ${req.uri.path}');
        print('Method: ${req.method}');
        
        router.handleRequest(req);
      });
    });
  }

  void initialize() {
    router.add((req) => req.uri.path.startsWith('/users/'))
      .listen((HttpRequest req) {
        print('Inside /users/ request');
        
        var myRouter = new RequestRouter();
        myRouter.add((req) => req.uri.path.startsWith('/users/list/'))
          .listen((HttpRequest myReq) {
            print('Inside /users/list/ request');
            
            var resp = req.response;
            resp.addString('Got Users/List!');
            resp.close();
          });
        
        myRouter.add((req) => req.uri.path.startsWith('/users/show/'))
          .listen((HttpRequest req) {
            print('Inside /users/show/ request');
            
            var resp = req.response;
            resp.addString('Got Users/Show!');
            resp.close();
          });
        
        myRouter.defaultRoute.listen((req) {
          print('Inside default for /users/ router');
          
          var resp = req.response;
          resp.addString('Got Users!');
          resp.close();
        });
        
        myRouter.handleRequest(req);
        
      });
    
    router.add((req) => req.uri.path.startsWith('/blarg/'))
    .listen((HttpRequest req) {
      print('Inside /blarg/ route! slick!');
      req.response.addString('Blarg yourself!');
      req.response.close();
    });
    
    router.defaultRoute.listen((HttpRequest req) {
      print('Inside default route');
      
      req.response.addString('default route');
      req.response.close();
    });
  }
}

main() {
  var server = new SampleServer();
  server.initialize();
  server.run();
}
