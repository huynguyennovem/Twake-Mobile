import 'package:flutter/material.dart';
import 'package:twake/blocs/sheet_bloc.dart';

class DraggableScrollable extends StatelessWidget {
  final SheetFlow flow;

  const DraggableScrollable({Key key, this.flow}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        builder: (BuildContext context, ScrollController scrollController) {
      return Container(
        color: Colors.blue[100],
        child: ListView.builder(
          controller: scrollController,
          itemCount: 25,
          itemBuilder: (BuildContext context, int index) {
            return ListTile(title: Text('Item $index'));
          },
        ),
      );
    });
  }
}
