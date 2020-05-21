import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

final small = TextStyle(fontFamily: "Mario", fontSize: 50);
final big = TextStyle(fontFamily: "Mario", fontSize: 100);
final huge = TextStyle(fontFamily: "Mario", fontSize: 150);

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Math Flash',
      theme: ThemeData(
        primarySwatch: Colors.red,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LevelSelector(),
    );
  }
}

class LevelSelector extends StatelessWidget {
  LevelSelector({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Math Flash'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FlatButton(
              child: Text('Numbers 1-5', style: big),
              onPressed: () => numbers(context, min: 1, max: 5, step: 1),
            ),
            SizedBox(height: 48),
            FlatButton(
              child: Text('Numbers 1-10', style: big),
              onPressed: () => numbers(context, min: 1, max: 10, step: 1),
            )
          ],
        ),
      ),
    );
  }

  void numbers(BuildContext context, {int min, int max, int step}) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NumberMatchGame(min: min, max: max, step: step),
        ));
  }
}

class NumberMatchGame extends StatefulWidget {
  final int min;
  final int max;
  final int step;

  NumberMatchGame({Key key, this.min, this.max, this.step}) : super(key: key);

  @override
  _NumberMatchGameState createState() => _NumberMatchGameState();
}

enum Phase {
  starting,
  playing,
  done,
}

class _Match extends Comparable<_Match> {
  final int number;
  int correct = 0;
  int incorrect = 0;
  Duration time = Duration.zero;
  Duration lastTime = Duration.zero;
  int _initial;

  _Match(this.number, Random rnd) {
    _initial = rnd.nextInt(100);
  }

  @override
  int compareTo(_Match other) {
    if (_initial != null) return -_initial - 100;

    return (correct - incorrect - lastTime.inSeconds - time.inSeconds / 3).toInt();
  }

  void record(bool errored, Duration elapsed) {
    if (_initial != null) {
      _initial = null;
    }
    if (errored)
      incorrect++;
    else
      correct++;
    time += elapsed;
    lastTime = elapsed;
  }
}

class _NumberMatchGameState extends State<NumberMatchGame> {
  Phase phase = Phase.starting;
  int score;
  int time = 60;
  Timer timer;
  Stopwatch answerTimer;
  List<_Match> matches;
  bool errored = false;
  Sounds sounds = Sounds();

  @override
  void initState() {
    super.initState();

    final rnd = Random();
    matches = [for (int i = widget.min; i <= widget.max; i += widget.step) _Match(i, rnd)];
  }

  void next() {
    if (phase == Phase.starting) {
      phase = Phase.playing;
      sounds.start();
      answerTimer = Stopwatch();
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          time--;
          if (time == 0) {
            phase = Phase.done;
            timer.cancel();
            answerTimer.stop();
            sounds.stop();
            if (score >= 30)
              sounds.bigwin();
            else
              sounds.win();
          }
        });
      });
      score = 0;
    } else {
      sounds.correct();
      if (!errored) {
        score++;
      }
      matches[0].record(errored, answerTimer.elapsed);
    }
    errored = false;
    answerTimer.reset();
    matches.shuffle();
    matches.sort();
  }

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case Phase.starting:
        return StartTimer(
          sounds: sounds,
          onReady: () {
            setState(next);
          },
        );
      case Phase.playing:
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(children: [Text("Score: $score", style: small), Spacer(), Text(time.toString(), style: small)]),
            Spacer(),
            Center(child: FiveFrame.redCounters(matches[0].number)),
            if (widget.max > 5) Center(child: FiveFrame.whiteCounters(matches[0].number - 5)),
            Spacer(),
            for (final group in options()) Center(child: FiveFrame(group)),
            Spacer(),
          ],
        );
        break;
      case Phase.done:
        return Center(child: Text("You got ${score}", style: huge));
        break;
    }
  }

  Iterable<List<Widget>> options() sync* {
    List<Widget> group = [];
    for (int i = widget.min; i <= widget.max; i += widget.step) {
      group.add(buildFlatButton(i));
      if (group.length == 5) {
        yield group;
        group = [];
      }
    }
    if (group.length > 0) {
      while (group.length < 5) group.add(Counter.none());
      yield group;
    }
  }

  FlatButton buildFlatButton(int i) {
    return FlatButton(
      child: Text(i.toString(), style: small),
      onPressed: () {
        if (i == matches[0].number) {
          setState(next);
        } else {
          errored = true;
          sounds.error();
        }
      },
    );
  }
}

class StartTimer extends StatefulWidget {
  final VoidCallback onReady;
  final Sounds sounds;

  const StartTimer({Key key, this.sounds, this.onReady}) : super(key: key);

  @override
  _StartTimerState createState() => _StartTimerState();
}

class _StartTimerState extends State<StartTimer> with TickerProviderStateMixin {
  AnimationController controller;
  int n;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          n--;
          widget.sounds?.startTimerBeep();
          if (n > 0) {
            controller.forward(from: 0);
          } else {
            widget.onReady();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (n == null) {
      return Center(
          child: FlatButton(
        child: Text(
          "Start!",
          style: big,
        ),
        onPressed: () {
          setState(() {
            n = 3;
            controller.forward(from: 0);
          });
        },
      ));
    } else {
      return Center(
          child: Text(
        n.toString(),
        style: huge,
      ));
    }
  }
}

class FiveFrame extends StatelessWidget {
  final List<Widget> cells;

  FiveFrame(this.cells);

  factory FiveFrame.redCounters(int c) => FiveFrame.counters(c, Counter.red());

  factory FiveFrame.whiteCounters(int c) => FiveFrame.counters(c, Counter.white());

  factory FiveFrame.counters(int c, Widget counter) =>
      FiveFrame([for (int x = 0; x < min(5, c); x++) counter, for (int x = max(0, c); x < 5; x++) Container()]);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cell in cells)
            Container(
              decoration: BoxDecoration(border: Border.all()),
              padding: EdgeInsets.all(10),
              width: 100,
              height: 100,
              child: cell,
            )
        ],
      );
}

class Counter extends StatelessWidget {
  final Color color;

  Counter(this.color);

  Counter.red() : this(Colors.red);

  Counter.white() : this(Colors.grey);

  Counter.none() : this(Colors.transparent);

  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: ShapeDecoration(color: color, shape: CircleBorder()));
}

class Sounds {
  AudioCache player;
  AudioPlayer music;

  Sounds() {
    player = AudioCache(prefix: 'sounds/');
    player.loadAll([
      'smb_bump.wav',
      'smb_1-up.wav',
      'music.mp3',
      'smb_fireworks.wav',
      'smb_stage_clear.wav',
      'smb_world_clear.wav',
    ]);
  }

  error() {
    player.play('smb_bump.wav');
  }

  correct() {
    player.play('smb_1-up.wav');
  }

  start() async {
    await stop();
    music = await player.loop('music.mp3');
  }

  stop() async {
    if (music != null) {
      await music.stop();
      music = null;
    }
  }

  void startTimerBeep() {
    player.play('smb_fireworks.wav');
  }

  void win() {
    player.play('smb_stage_clear.wav');
  }

  void bigwin() {
    player.play('smb_world_clear.wav');
  }
}