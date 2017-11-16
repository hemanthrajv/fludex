# Fludex :fire:
##

##### Flutter + Redux = Fludex
A redux based state managment library specialy build only for Flutter.

### Why Fludex?

* It is specialy built for Flutter and only works with Flutter.
* It makes it easy to connect to store
* It has built-in logger, thunk and futureMiddlewares
* It uses simple wrapper to rebuild UI based on store


## Basics
### FludexState:
The application state is always of type `FludexState`. FludexState is implemented to make the state typesafe.

example:
```dart
FludexState<int> initState = new FludexState<int>(0);
```

### Actions:
Fludex has a `Action` type. Any action dispatched to the store should be of type `Action`.
The `Action` take two arguments `type` and `payload` (optional). The `type` defines what is the Type of Action and `payload` is some additional data dispatched to store.

example:
```dart

// A normal string action
Action stringAction = new Action(type: "SOME_ACTION",payload:"SOME_PAYLOAD");


// A [FutureAction] that can only be handled by [futureMiddleware].
Future<String> future = new Future<String>.delayed(
                          new Duration(seconds: 5),
                          () => "FutureAction Resolved");

Action futureAction = new Action(type: new FutureAction<String>(future));


// A [Thunk] action that is handled by [thunk] middleware.
Thunk thunkAction = (Store store) async {
    final int value =
        await new Future<int>.delayed(new Duration(seconds: 3), () => 0);
    store.dispatch(new Action(type: "UPDATE", payload: value));
  };

```

### Reducers:
There is a `Reducer` type that takes `initState` (optional) and a `StateReducer` function as argument.

A `StateReducer` is a normal function that gets `state` and `action` as arguments, alters the state based on action and returns the new `state`.

```dart

// State
FludexState<int> initState = new FludexState<int>(0);

// Reducer function of type StateReducer
FludexState reducerFunction(FludexState fludexState, Action action){
    int state = fludexState.state;
	if(action.type == "INC")
    	state++;
    return new FludexState(state);
}

// Reducer
Reducer reducer = new Reducer(initState:initState,reduce:reducerFunction);

```

You can combine multiple reducers with built-in `CombineReducer`.

`CombineReducer` takes a `Map<String,Reducer>` as input. When using `CombineReducer` the state will be `Map<String,dynamic>` and the keys of reducer's map is used to build the state.
```dart

// Reducer-1
Reducer reducer1 = new Reducer(initState:initState1,reduce:reducerFunction1);

// Reducer-2
Reducer reducer2 = new Reducer(initState:initState2,reduce:reducerFunction2);

// Root Reducer
Reducer rootReducer = new CombineReducer({
                         "Screen1": reducer1
                         "Screen2": reducer2
                        });

// if initState1 = 0 and initState2 = 0, after applying CombineReducer the state will be { "Screen1":0, "Screen2":0 }

```

### Store:
A fludex store has the following responsibilites.
>* Ensure only one instance of the store exists all over the application
>* Holds application state.
>* Allows access to state.
>* Allows to dispatch actions.
>* Registers listeners via [subscribe]

You should create a store before calling `runApp`.

`Store` take a single argument of type `Map<String,dynamic>` in which we specify the reducers and middlewares.

example:
```dart

// StateReducer
  final Reducer reducer = new CombinedReducer(
    {
      HomeScreen.name: HomeScreen.reducer,
      SecondScreen.name: SecondScreen.reducer
    }
  );

// Store Params
final Map<String, dynamic> params = <String, dynamic>{"reducer":reducer, "middleware": <Middleware>[logger, thunk, futureMiddleware]};

// Create the Store with params for first time.
final Store store = new Store(params);

// Run app
runApp(new MaterialApp(
          home: new HomeScreen(),
          routes: <String, WidgetBuilder>{
          HomeScreen.name: (BuildContext context) => new HomeScreen(),
          SecondScreen.name: (BuildContext context) => new SecondScreen()
       },));

```

Once `Store` created, one can easily connect to the store with `StoreWrapper`. `StoreWrapper` takes a builder function which is normal function that returns a `Widget` connected to some `state` via `Store`. Once store created you can get the state by creating new instance with `null` as params.
```
// If initState of Home is String initState = "Hello World!"
new StoreWrapper(
	builder: () => new Text(new Store(null).state["Home"]);
);
```

### Middleware:
`Middleware` is somecode put between the dispatched action and the reducer receiving the action.
`Middleware` is a normal function type that receives `Store`,`Action` and `NextDispatcher` as arguments. You can build your own middleware.

example:
```dart
// Example logger middleware
Middleware logger = (Store store, Action action, NextDispatcher next) {
       print('${new DateTime.now()}: $action');
       next(action);
     }

```

##### Built-in Middlewares:

##### logger:
A built-in logger middleware logs the Action, PreviousState, NextState and TimeStamp when applied.

example logs:
```
I/flutter ( 3949): [INFO] Fludex Logger: {
I/flutter ( 3949):   Action: FUTURE_DISPATCHED,
I/flutter ( 3949):   Previous State: {HomeScreen: 0, SecondScreen: {state: Begin, count: 0, status: FutureAction yet to be dispatched, loading: false}},
I/flutter ( 3949):   Next State: {HomeScreen: 0, SecondScreen: {state: Begin, count: 0, status: FutureAction Dispatched, loading: true}},
I/flutter ( 3949):   Timestamp: 2017-11-09 14:33:58.935510
I/flutter ( 3949): }
I/flutter ( 3949): [INFO] Fludex Logger: {
I/flutter ( 3949):   Action: FutureFulfilledAction{result: FutureAction Resolved},
I/flutter ( 3949):   Previous State: {HomeScreen: 0, SecondScreen: {state: Begin, count: 0, status: FutureAction Dispatched, loading: true}},
I/flutter ( 3949):   Next State: {HomeScreen: 0, SecondScreen: {state: Begin, count: 0, status: FutureAction Resolved, loading: false}},
I/flutter ( 3949):   Timestamp: 2017-11-09 14:34:03.919460
I/flutter ( 3949): }
```

##### thunk:
Built-in thunk middleware that is capable of handling `Thunk` actions.
A `Thunk` action is just a function that takes `Store` as argument.

example:
```dart
// Example Thunk action
Thunk action = (Store store) async {
       final result = await new Future.delayed(
           new Duration(seconds: 3),
           () => "Result",
        );
       store.dispatch(result);
     };
```

##### futureMiddleware:
A built-in `futureMiddleware` that handles dispatching results of [Future] to the [Store]


The `Future` or `FutureAction` will be intercepted by the middleware. If the
future completes successfully, a `FutureFulfilledAction` will be dispatched
with the result of the future. If the future fails, a `FutureRejectedAction`
will be dispatched containing the error that was returned.


 example:
 ```dart
 // First, create a reducer that knows how to handle the FutureActions:
 // `FutureFulfilledAction` and `FutureRejectedAction`.
 FludexState exampleReducer(FludexState fludexState,Action action) {
   String state = fludexState.state;
   if (action is String) {
   return action;
   } else if (action is FutureFulfilledAction) {
   return action.result;
   } else if (action is FutureRejectedAction) {
   return action.error.toString();
   }

  return new FludexState<String>(state);
}

// Next, create a Store that includes `futureMiddleware`. It will
// intercept all `Future`s or `FutureAction`s that are dispatched.
final store = new Store(
  {
    "reducer": exampleReducer,
    "middleware": [futureMiddleware],
  }
);

// In this example, once the Future completes, a `FutureFulfilledAction`
// will be dispatched with "Hi" as the result. The `exampleReducer` will
// take the result of this action and update the state of the Store!
store.dispatch(new Future(() => "Hi"));

// In this example, the initialAction String "Fetching" will be
// immediately dispatched. After the future completes, the
// "Search Results" will be dispatched.
store.dispatch(new FutureAction(
                  new Future(() => "Search Results"),
                  initialAction: "Fetching"
               ));

// In this example, the future will complete with an error. When that
// happens, a `FutureRejectedAction` will be dispatched to your store,
// and the state will be updated by the `exampleReducer`.
store.dispatch(new Future.error("Oh no!"));

```

## Example

#### main function
```dart
void main(){

  // StateReducer
  final Reducer reducer = new CombinedReducer(
    {
      HomeScreen.name: HomeScreen.reducer,
      SecondScreen.name: SecondScreen.reducer
    }
  );

  // Store Params
  final Map<String, dynamic> params = <String, dynamic>{"reducer":reducer, "middleware": <Middleware>[logger, thunk, futureMiddleware]};

  // Create the Store with params for first time.
  final Store store = new Store(params);

  // Run app
  runApp(new MaterialApp(
    home: new HomeScreen(),
    routes: <String, WidgetBuilder>{
      HomeScreen.name: (BuildContext context) => new HomeScreen(),
      SecondScreen.name: (BuildContext context) => new SecondScreen()
    },
  ));
}
```

#### HomeScreen

```dart
class HomeScreen extends StatelessWidget {
  //Identifier for HomeScreen
  static final String name = "HomeScreen";

  // Reducer for HomeScreen
  static final Reducer reducer =
      new Reducer(initState: initState, reduce: _reducer);

  // Initial State of HomeScreen
  static final FludexState<int> initState = new FludexState<int>(0);

  // StateReducer function for HomeScreen
  static FludexState _reducer(FludexState fludexState, Action action) {
    int state_ = fludexState.state;
    if (action.type == "INC") state_++;
    if (action.type == "DEC") state_--;
    if (action.type == "UPDATE") state_ = action.payload;
    return new FludexState<int>(state_);
  }

  // Dispatches a "INC" action
  void _incrementCounter() {
    new Store(null).dispatch(new Action<String, Object>(type: "INC"));
  }

  // Dispatches a "DEC" action
  void _decrementCounter() {
    new Store(null).dispatch(new Action<String, Object>(type: "DEC"));
  }

  // A Thunk action that resets the state to 0 after 3 seconds
  static Thunk thunkAction = (Store store) async {
    final int value =
        await new Future<int>.delayed(new Duration(seconds: 3), () => 0);
    store.dispatch(new Action(type: "UPDATE", payload: value));
  };

  // Dispatches a thunkAction
  void _thunkAction() {
    new Store(null).dispatch(new Action(type: thunkAction));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text("HomeScreen"),
      ),
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new StoreWrapper(
              builder: () =>
                  new Text(new Store(null).state[HomeScreen.name].toString())),
          new Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              new IconButton(
                  icon: new Icon(Icons.arrow_back),
                  onPressed: _decrementCounter),
              new IconButton(
                  icon: new Icon(Icons.arrow_forward),
                  onPressed: _incrementCounter)
            ],
          ),
          const Text(
            "Dispatch a Thunk Action which resolves a future and resets the store once future resolved",
            textAlign: TextAlign.center,
          ),
          new FlatButton(
              onPressed: _thunkAction,
              child: const Text("Dispatch Thunk Action"))
        ],
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: () => Navigator.of(context).pushNamed(SecondScreen.name),
        tooltip: 'Go to SecondScreen',
        child: new Icon(Icons.arrow_forward),
      ),
    );
  }
}

```
#### SecondScreen
```dart
class SecondScreen extends StatelessWidget {
  // Identifier for SecondScreen
  static final String name = "SecondScreen";

  // Reducer for SecondScreen
  static final Reducer reducer =
      new Reducer(initState: initState, reduce: _reducer);

  // Initial state of the screen
  static final FludexState<Map<String, dynamic>> initState = new FludexState<Map<String,dynamic>>(<String, dynamic>{
    "state": "Begin",
    "count": 0,
    "status": "FutureAction yet to be dispatched",
    "loading": false
  });

  // StateReducer function that mutates the state of the screen.
  // Reducers are just functions that knows how to handle state changes and retuns the changed state.
  static FludexState _reducer(FludexState _state, Action action) {
    Map<String, dynamic> state = _state.state;
    if (action.type == "CHANGE") {
      state["state"] = "Refreshed";
      state["count"]++;
    } else if (action.type is FutureFulfilledAction) {
      state["loading"] = false;
      state["status"] = action.type
          .result; // Result is be the value returned when a future resolves
      Navigator.of(action.payload["context"]).pop();
    } else if (action.type is FutureRejectedAction) {
      state["loading"] = false;
      state["status"] =
          action.type.error; // Error is the reason the future failed
      Navigator.of(action.payload["context"]).pop();
    } else if (action.type == "FUTURE_DISPATCHED") {
      state["status"] = action.payload["result"];
      state["loading"] = true;
      _onLoading(action.payload["context"]);
    }

    return new FludexState<Map<String,dynamic>>(state);
  }

  static void _onLoading(BuildContext context) {
    showDialog<dynamic>(
        context: context,
        barrierDismissible: false,
        child: new Container(
          padding: const EdgeInsets.all(10.0),
          child: new Dialog(
            child: new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const CircularProgressIndicator(),
                const Text("Loading"),
              ],
            ),
          ),
        ));
  }

  // Dispatches a simple action with no Payload
  void _change() {
    new Store(null).dispatch(new Action<String, Object>(type: "CHANGE"));
  }

  // Builds and dispatches a FutureAction
  void _delayedAction(BuildContext context) {

    // A dummyFuture that resolves after 5 seconds
    final Future<String> dummyFuture = new Future<String>.delayed(
        new Duration(seconds: 5), () => "FutureAction Resolved");

    // An Action of type [FutureAction] that takes a Future to be resolved and a initialAction which is dispatched immedietly.
    final Action asyncAction = new Action(
        type: new FutureAction<String>(dummyFuture,
            initialAction: new Action(type: "FUTURE_DISPATCHED", payload: {
              "result": "FutureAction Dispatched",
              "context": context
            })),
        payload: {"context": context});

    // Dispatching a FutureAction
    new Store(null).dispatch(asyncAction);
  }

  // Builds a Text widget based on state
  Widget _buildText1() {

    final Map<String, dynamic> state = new Store(null).state[SecondScreen.name];
    final String value = state["state"] + " " + state["count"].toString();

    return new Container(
      padding: const EdgeInsets.all(20.0),
      child: new Text(value),
    );
  }

  // Builds a Text widget based on state
  Widget _buildText2() {

    final bool loading = new Store(null).state[SecondScreen.name]["loading"];

    return new Center(
      child: new Text(
        "Status: " + new Store(null).state[SecondScreen.name]["status"],
        style:
        new TextStyle(color: loading ? Colors.red : Colors.green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: const Text("SecondScreen"),
      ),
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          new StoreWrapper(builder: _buildText1),
          const Text(
            "Dispatch a FutureAction that resolves after 5 seconds",
            textAlign: TextAlign.center,
          ),
          new StoreWrapper(builder: _buildText2),
          new FlatButton(
              onPressed: () => _delayedAction(context),
              child: const Text("Dispatch a future action"))
        ],
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _change,
        tooltip: 'Refresh',
        child: new Icon(Icons.refresh),
      ),
    );
  }
}

```

To run the example.


>* git clone https://github.com/hemanthrajv/fludex.git
>* cd /path to cloned dir/
>* cd example
>* flutter run



##


### Author:

**Hemanth Raj**

[LinkedIn](https://www.linkedin.com/in/hemanthrajv)


###### Built With :
[Flutter](https://flutter.io) - A framework for building crossplatform mobile applications.


###### References : [redux.dart](https://pub.dartlang.org/packages/redux), [redux-logger](https://pub.dartlang.org/packages/redux_logging), [redux-thunk](https://pub.dartlang.org/packages/redux_thunk) & [redux-future](https://pub.dartlang.org/packages/redux_future)
