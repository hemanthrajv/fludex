import 'package:fludex/fludex.dart';
import 'package:flutter/material.dart';
import 'example.dart';

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
