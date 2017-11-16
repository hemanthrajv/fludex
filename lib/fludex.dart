library fludex;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// A builder function type. A Builder function is a function with no arguments and returns a widget connected to the store.
///
///
/// example:
///     builder: () => Text(new Store(null).state["StateName"].someValue);
///
typedef Widget Builder();

/// The type of a dispacher.
typedef void NextDispatcher(Action action);

/// The type of a Thunk Action.
typedef void Thunk(Store store);

/// The type of a Reducer function. A reducer function is provided as an argunment to the [Reducer] along with [initState].
/// A reducer function will receives a state (respective state based on initState in case of multiple reducers) and action as arguments.
/// The state is changed based on the action and a new state is returned.
///
///
/// example:
///       FludexState exampleReducer(FludexState state_, Action action){
///         String state = state_.state
///         if(action == "change"){
///           state = "changed";
///         }
///         return new FludexState(state);
///       }
typedef FludexState<T> StateReducer<T>(FludexState<T> state, Action action);

/// The type of Middleware functions. All middlewares are functions
/// that receive [Store],[Action] and [NextDispatcher] as arguments.
///
///
/// example:
///       logger(Store store, Action action, NextDispatcher next){
///         print("Logger: "+store.state.toString());
///         next(action);
///       }
typedef dynamic Middleware(Store store, Action action, NextDispatcher next);


/// Type of the app state
class FludexState<T>{
  final T _state;

  FludexState(this._state);

  T get state => _state;

  dynamic operator [](String key){
    // ignore: undefined_operator
    if (_state is Map && _state[key] is FludexState){
      // ignore: undefined_operator
      return _state[key].state;
    }else{
      return _state;
    }
  }

  @override
  String toString(){
    return _state.toString();
  }
}

class Action<S, T> {
  final S type;

  final T payload;

  Action({@required this.type, this.payload});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType;

  @override
  int get hashCode => type.hashCode ^ payload.hashCode;

  @override
  String toString() {
    return type.toString();
  }
}

/// A Default logger used when logger middleware used.
class DefaultFludexLogger {
  static DefaultFludexLogger _logger;

  Logger _fludexLogger = new Logger("Fludex Logger");

  Level _fludexLoggerLevel = Level.INFO;

  factory DefaultFludexLogger() {
    if (_logger != null) return _logger;
    _logger = new DefaultFludexLogger._internal();
    return _logger;
  }

  DefaultFludexLogger._internal() {
    _fludexLogger.onRecord
        .where((record) => record.loggerName == logger.name)
        .listen((data) => print(data));
  }

  Logger get logger => _fludexLogger;

  Level get level => _fludexLoggerLevel;

  void set level(Level l) {
    _fludexLoggerLevel = l;
  }
}

/// [logger] is a built-in logging middleware.
dynamic logger(Store store, Action action, NextDispatcher next) {
  final DefaultFludexLogger _logger = new DefaultFludexLogger();
  if (!const bool.fromEnvironment("dart.vm.product")) {
    String log = "{\n" +
        "  Action: ${action.toString()},\n" +
        "  Previous State: ${store.state.toString()},\n";
    // ignore: use_of_void_result
    final dynamic result = next(action);
    log = log +
        "  Next State: ${store.state.toString()},\n" +
        "  Timestamp: ${new DateTime.now()}\n" +
        "}";
    _logger.logger.log(_logger.level, log);
    return result;
  }
  return next(action);
}

/// [thunk] is a built-in thunk middleware that is capable of handling [Thunk] actions.
/// A [Thunk] action is just a function that takes [Store] as argument.
///
///
/// example:
///         Thunk action = (Store store) async {
///           final result = await new Future.delayed(
///               new Duration(seconds: 3),
///               () => "Result",
///            );
///           store.dispatch(result);
///         };
void thunk(Store store, Action action, NextDispatcher next) {
  if (action.type is Thunk) {
    action.type(store);
  } else {
    next(action);
  }
}

/// A built-in [futureMiddleware] that handles dispatching results of [Future] to the [Store]
///
///
/// The [Future] or [FutureAction] will be intercepted by the middleware. If the
/// future completes successfully, a [FutureFulfilledAction] will be dispatched
/// with the result of the future. If the future fails, a [FutureRejectedAction]
/// will be dispatched containing the error that was returned.
///
///
/// example:
///     // First, create a reducer that knows how to handle the FutureActions:
///     // `FutureFulfilledAction` and `FutureRejectedAction`.
///     FludexState exampleReducer(FludexState state_,Action action) {
///       String state = state_.state;
///       if (action is String) {
///         return action;
///       } else if (action is FutureFulfilledAction) {
///         return action.result;
///       } else if (action is FutureRejectedAction) {
///         return action.error.toString();
///       }
///
///       return state;
///     }
///
///     // Next, create a Store that includes `futureMiddleware`. It will
///     // intercept all `Future`s or `FutureAction`s that are dispatched.
///     final store = new Store(
///       {
///         "reducer": exampleReducer,
///         "middleware": [futureMiddleware],
///       }
///     );
///
///     // In this example, once the Future completes, a `FutureFulfilledAction`
///     // will be dispatched with "Hi" as the result. The `exampleReducer` will
///     // take the result of this action and update the state of the Store!
///     store.dispatch(new Future(() => "Hi"));
///
///     // In this example, the initialAction String "Fetching" will be
///     // immediately dispatched. After the future completes, the
///     // "Search Results" will be dispatched.
///     store.dispatch(new FutureAction(
///       new Future(() => "Search Results"),
///       initialAction: "Fetching"));
///
///     // In this example, the future will complete with an error. When that
///     // happens, a `FutureRejectedAction` will be dispatched to your store,
///     // and the state will be updated by the `exampleReducer`.
///     store.dispatch(new Future.error("Oh no!"));
void futureMiddleware(Store store, Action action, NextDispatcher next) {
  if (action.type is FutureAction) {
    if (action.type.initialAction != null) {
      next(action.type.initialAction);
    }

    _dispatchResults(store, action.type.future, action.payload);
  } else if (action is Future) {
    _dispatchResults(store, action.type, action.payload);
  } else {
    next(action);
  }
}

// Dispatches the result of a future to the Store.
void _dispatchResults(Store store, Future<dynamic> future, dynamic payload) {
  future
      .then((dynamic result) => store.dispatch(
          new Action<FutureFulfilledAction<dynamic>, Object>(
              type: new FutureFulfilledAction<dynamic>(result),payload: payload)))
      .catchError((dynamic error) => store.dispatch(
          new Action<FutureRejectedAction<dynamic>, Object>(
              type: new FutureRejectedAction<dynamic>(error),payload: payload)));
}

/// [FutureAction] will dispatch the result of a [Future] to the [Store].
/// It also takes optional argument [initialAction] which is immediately dispatched.
class FutureAction<T> {
  final Future<T> future;

  final dynamic initialAction;

  FutureAction(
    this.future, {
    this.initialAction,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FutureAction &&
          runtimeType == other.runtimeType &&
          initialAction == other.initialAction &&
          future == other.future;

  @override
  int get hashCode => initialAction.hashCode ^ future.hashCode;

  @override
  String toString() {
    return 'AsyncAction{initialAction: ${initialAction
        .toString()}, future: ${future.toString()}}';
  }
}

/// This action will be dispatched if the [Future] provided to a [FutureAction]
/// completes successfully.
class FutureFulfilledAction<T> {
  final T result;

  FutureFulfilledAction(this.result);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FutureFulfilledAction &&
          runtimeType == other.runtimeType &&
          result == other.result;

  @override
  int get hashCode => result.hashCode;

  @override
  String toString() {
    return 'FutureFulfilledAction{result: ${result.toString()}}';
  }
}

/// This action will be dispatched if the [Future] provided to a [FutureAction]
/// finishes with an error.
class FutureRejectedAction<E> {
  final E error;

  FutureRejectedAction(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FutureRejectedAction &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() {
    return 'FutureRejectedAction{error: ${error.toString()}}';
  }
}

/// [Reducer] is responsible for maintaining respective state.
/// It takes an optional [initState] argument which will be the initial state for the reducer.
class Reducer {
  FludexState initState;

  StateReducer reduce;

  Reducer({this.initState, @required this.reduce}) {
    if (reduce == null) {
      throw "Reducer Function cannot be null";
    }
  }
}

/// [CombineReducer] is used to combine multiple [Reducer]'s into a single [Reducer].
/// It takes [Map] of [String] and [Reducer] as argument and creates a state such that,
/// the [String] keys are mapped to the initState of each [Reducer]s.
/// The [Reducer] also receives this state and a action as argument.
///
///
/// example:
///         StateReducer reducerFun1 = (FludexState state_, Action action){
///           int state = state_.state;
///           if(action is "INC"){
///             state = state + 1;
///           }
///           if(action is "DEC"){
///             state = state - 1;
///           }
///           return new FludexState(state);
///         }
///
///         StateReducer reducerFun2 = (FludexState state_, Action action){
///           int state = state_.state;
///           if(action is "ADD_5"){
///             state = state + 5;
///           }
///           if(action is "SUB_5"){
///             state = state - 5;
///           }
///           return new FludexState(state);
///         }
///
///         // Here initialState of HomeScreen is defined by initState of homeScreenReducer.
///         // reducerFun1 is responsible for handling HomeScreen State.
///         Reducer homeScreenReducer = new Reducer(initState: 0, reduce: reducerFun1);
///
///         // Here initialState of Second is defined by initState of secondScreenReducer.
///         // reducerFun2 is responsible for handling SecondScreen State.
///         Reducer secondScreenReducer = new Reducer(initState: 0, reduce: reducerFun2);
///
///         Reducer rootReducer = new CombineReducer({
///                                                   "HomeScreen": homeScreenReducer,
///                                                   "SecondScreen": secondScreenReducer
///                                                   });
///
///         Store store = new Store({"reducer":rootReducer});
class CombinedReducer implements Reducer {
  @override
  FludexState initState;

  @override
  StateReducer reduce;

  List<Reducer> _reducers = <Reducer>[];

  CombinedReducer(Map<String, Reducer> reducers) {
    Map<String, FludexState> init = new Map<String,FludexState>();
    reduce = _reducer;
    reducers.forEach((String key, Reducer reducer) {
       init[key] = reducer.initState;
      _reducers.add(reducer);
    });
    initState = new FludexState<Map<String,FludexState>>(init);

    //_reducers = reducers;
  }

  FludexState _reducer(FludexState state, Action action) {
    final FludexState prevState = state;
    List<String> keys = new List.from(state.state.keys);
    for(int i = 0;i<_reducers.length;i++){
      Reducer reducer = _reducers[i];
      final FludexState nextState = reducer.reduce(state.state[keys[i]], action);
      state.state[keys[i]] = nextState;
    };
    return state != prevState ? state : prevState;
  }
}

/// [StoreWrapper] is a wrapper widget that takes a [Builder] function as argument.
/// Here [Builder] function is just a normal function that takes no arguments but returns a [Widget] connected to store.
///
///
/// example:
///         // The example shows a Text Widget connected to store.
///         Widget text = new StoreWrapper( builder: () => new Text(new Store(null).state["HomeScreen"].text));
///
class StoreWrapper extends StatefulWidget {
  final Builder builder;

  StoreWrapper({Key key, @required this.builder}) : super(key: key);

  @override
  _StoreWrapperState createState() => new _StoreWrapperState();
}

class _StoreWrapperState extends State<StoreWrapper> {
  @override
  Widget build(BuildContext context) {
    return new StreamBuilder<dynamic>(
      builder: (context, snap) {
        final Widget child = widget.builder();
        return child;
      },
      stream: new Store(null).getStream,
    );
  }
}

/// [Store] defines a fludex store.
/// [Store] has the following responsibilites.
///        * Holds application state.
///        * Allows access to state.
///        * Allows to dispatch actions.
///        * Registers listeners via [subscribe]
class Store {
  // The store instance returned whenever a store is created.
  static Store _store;

  // The stream that controls the state changes.
  final StreamController<dynamic> _stateController =
      new StreamController<dynamic>.broadcast();

  // The reducer for the store.
  Reducer _reducer;

  // Holds the state of the application.
  // In case of only on reducer state will be of type defined by initstate of Reducer or null.
  // In case of multiple reducers combined with combine reducers,
  // state will be a Map<String, State> having respective keys of the reducers for respective states.
  FludexState _state;

  // List of Middlewares that can be applied to the state.
  List<Middleware> _middlewares = [];

  // List of action dispatchers.
  List<NextDispatcher> _dispatchers = [];

  // Constructor
  factory Store(Map<String, dynamic> params) {
    if (_store != null) return _store;
    _store = new Store._internal(params);
    return _store;
  }

  Store._internal(Map<String, dynamic> params) {
    if (params == null) {
      throw new Exception("Params cannot be null");
    } else {
      _reducer = params["reducer"];
      _state = _reducer.initState;
      _middlewares = params["middleware"];
      _dispatchers = _getDispatchers(_middlewares);
    }
  }

  List<NextDispatcher> _getDispatchers(List<Middleware> middlewares) {
    final List<NextDispatcher> dispatchers = [];
    dispatchers.add(_reduce);
    middlewares.forEach((Middleware middleware) {
      final NextDispatcher next = dispatchers.last;
      final NextDispatcher dispatcher =
          (Action action) => middleware(_store, action, next);
      dispatchers.add(dispatcher);
    });
    return dispatchers.reversed.toList();
  }

  // Allows access to application state.
  FludexState get state => _state;

  void _reduce(Action action) {
    final dynamic newState = _reducer.reduce(_state, action);
    _state = newState;
    _stateController.add(newState);
  }

  // Allows to subscribe to store.
  StreamSubscription<Function> subscribe(Function fun) {
    return _stateController.stream.listen(fun);
  }

  // Provides the store.
  Store get getStore => _store;

  //Provides the state stream
  Stream get getStream => _stateController.stream;

  // Allows to dispatch an action to the store.
  void dispatch(Action action) {
    _dispatchers[0](action);
  }
}
