import 'dart:async';

import 'package:fludex/fludex.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  //Identifier for HomeScreen
  static final String name = "HomeScreen";

  // Reducer for HomeScreen
  static final Reducer reducer =
      new Reducer(initState: initState, reduce: _reducer);

  // Initial State of HomeScreen
  static final int initState = 0;

  // StateReducer function for HomeScreen
  static int _reducer(int state, Action action) {
    if (action.type == "INC") state++;
    if (action.type == "DEC") state--;
    if (action.type == "UPDATE") state = action.payload;
    return state;
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

class SecondScreen extends StatelessWidget {
  // Identifier for SecondScreen
  static final String name = "SecondScreen";

  // Reducer for SecondScreen
  static final Reducer reducer =
      new Reducer(initState: initState, reduce: _reducer);

  // Initial state of the screen
  static final Map<String, dynamic> initState = <String, dynamic>{
    "state": "Begin",
    "count": 0,
    "status": "FutureAction yet to be dispatched",
    "loading": false
  };

  // StateReducer function that mutates the state of the screen.
  // Reducers are just functions that knows how to handle state changes and retuns the changed state.
  static Map<String, dynamic> _reducer(Map<String, dynamic> state, Action action) {

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

    return state;
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
