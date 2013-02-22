library SampleServer;

import 'dart:io';
import 'dart:async';


/**
 * Very simple router for [HttpRequest]s which replaces basic functionality of
 * addRequestHandler. Dispatches HttpRequests to first matching [Route]
 */
class RequestRouter {
  Set<Route> _routes;
  Route _default;
  
  RequestRouter() {
    _routes = new Set<Route>();
    _default = new Route((_) => true);
  }
  
  /**
   * Manually adds a [Route] object. Skips if Route rt is already added.
   * Routes should already event handlers attached.
   */
  void addRoute(Route rt) => _routes.add(rt);
  
  /**
   * Adds a new route via the matcher. Returns the new Route to allow
   * event handlers to be attached (via listen)
   */
  Route add(RouteMatcher rtMatch) {
    if(rtMatch == null) {
      throw new ArgumentError('RouteMatcher cannot be null');
    }
    var route = new Route(rtMatch);
    _routes.add(route);
    return route;
  }
  
  /**
   * Returns the default route to allow an event handler to be attached.
   */
  Route get defaultRoute => _default;
  
  
  /**
   * Accepts the incoming [HttpRequest] and tries to find a matching route.
   * If there are no matching Routes then the request is passed to the 
   * defaultRoute. If there is no eventHandler with the matching route, then
   * the [HttpResponse] is closed.
   * 
   */
  void handleRequest(HttpRequest req) {
    if(_routes.isEmpty) {
      // Handle this more gracefully.
      if(!_default.controller.hasSubscribers) {
        req.response.close();
      } else {
        _default.controller.add(req);
      }
      return;
    } 
    
    var rt = _routes.firstMatching((route) => route.matcher(req),
        orElse: () => _default);
    
    if(rt != null) {
      if(rt.controller.hasSubscribers) { 
        rt.controller.add(req);
      } else {
        req.response.close();
      }
    }
  }
}

/**
 * Route matchers should accept an [HttpRequest] and return a boolean value.
 */
typedef bool RouteMatcher(HttpRequest req);


/**
 * A route contains a [RouteMatcher], which when successful, dispatches
 * the incoming [HttpRequests] to the eventListener. 
 */
class Route extends Stream<HttpRequest> {
  StreamController<HttpRequest> controller;
  RouteMatcher matcher;
  
  Route(this.matcher) {
    controller = new StreamController<HttpRequest>();
  }
  
  /**
   * Subscribe to this route, passing at minimum, an eventHandler.
   */
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

/**
 * Very basic server class
 */
class SampleServer {
  /// Primary [RequestRouter]
  RequestRouter router;
  
  SampleServer() {
    router = new RequestRouter();
  }
  
  /// Start running the server
  void run() {
    HttpServer.bind('127.0.0.1', 8080).then((HttpServer server) {
      server.listen((HttpRequest req) {
        print('Path: ${req.uri.path}');
        print('Method: ${req.method}');
        
        router.handleRequest(req);
      });
    });
  }

  /// Initialize the routes.
  void initialize() {
    router.add((req) => req.uri.path.startsWith('/users/'))
      .listen((HttpRequest req) {
        print('Inside /users/ request');
        
        // Add a sub-router. Now we can add routes to this route.
        var myRouter = new RequestRouter();
        // Note: Still using the original path so we need to still
        // check for the /users/ portion. We could just as easily be
        // looking for a GET request method vs a POST request.
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
        
        // Anything not defined in a separate route will now execute here
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
