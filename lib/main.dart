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
              onPressed: () => numbers(
                context,
                max: 5,
              ),
            ),
            SizedBox(height: 48),
            FlatButton(
              child: Text('Numbers 1-10', style: big),
              onPressed: () => numbers(context, max: 10),
            ),
            SizedBox(height: 48),
            FlatButton(
              child: Text('Numbers 1-20', style: big),
              onPressed: () => numbers(context, max: 20, frameSize: 10),
            ),
            SizedBox(height: 48),
            FlatButton(
              child: Text('Doubles 1-10', style: big),
              onPressed: () => doubles(context, max: 20, frameSize: 10),
            )
          ],
        ),
      ),
    );
  }

  void numbers(BuildContext context, {int min = 1, int max, int step = 1, int frameSize = 5}) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NumberMatchGame(
            min: min,
            max: max,
            step: step,
            frameSize: frameSize,
          ),
        ));
  }

  void doubles(BuildContext context, {int min = 1, int max, int step = 1, int frameSize = 5}) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoubleMatchGame(
            min: min,
            max: max,
            step: step,
            frameSize: frameSize,
          ),
        ));
  }
}

abstract class FrameGameBase extends StatefulWidget {
  final int min;
  final int max;
  final int step;
  final int frameSize;

  FrameGameBase({Key key, this.min, this.max, this.step, this.frameSize = 5}) : super(key: key);
}

class NumberMatchGame extends FrameGameBase {
  NumberMatchGame({Key key, int min, int max, int step, int frameSize})
      : super(key: key, min: min, max: max, step: step, frameSize: frameSize);

  @override
  _NumberMatchGameState createState() => _NumberMatchGameState();
}

class DoubleMatchGame extends FrameGameBase {
  DoubleMatchGame({Key key, int min, int max, int step, int frameSize})
      : super(key: key, min: min, max: max, step: step, frameSize: frameSize);

  @override
  _DoubleMatchGameState createState() => _DoubleMatchGameState();
}

enum Phase {
  starting,
  playing,
  done,
}

abstract class _Token {
  int get number;

  int get answer;

  void record(bool errored, Duration elapsed);
}

class _Match extends _Token implements Comparable<_Match> {
  final int number;
  int correct = 0;
  int incorrect = 0;
  Duration time = Duration.zero;
  Duration lastTime = Duration.zero;
  int _initial;

  _Match(this.number, Random rnd) {
    _initial = rnd.nextInt(100);
  }

  int get answer => number;

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

class _DoubleMatch extends _Match {
  _DoubleMatch(int number, Random rnd) : super(number, rnd);

  @override
  int get answer => super.answer * 2;
}

abstract class _FrameGameStateBase<TWidget extends FrameGameBase, TToken extends _Token> extends State<TWidget> {
  Phase phase = Phase.starting;
  int score;
  int time = 60;
  Timer timer;
  Stopwatch answerTimer;
  List<TToken> matches;
  bool errored = false;
  Sounds sounds = Sounds();

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
            Center(child: redFrame(matches[0].number)),
            if (max > frameSize) Center(child: whiteFrame(matches[0].number - frameSize)),
            Spacer(),
            for (final group in options()) Center(child: frame(group)),
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
      if (group.length == frameSize) {
        yield group;
        group = [];
      }
    }
    if (group.length > 0) {
      while (group.length < frameSize) group.add(Counter.none());
      yield group;
    }
  }

  FlatButton buildFlatButton(int i) {
    return FlatButton(
      child: Text(i.toString(), style: small),
      onPressed: () {
        if (i == matches[0].answer) {
          setState(next);
        } else {
          errored = true;
          sounds.error();
        }
      },
    );
  }

  int get frameSize => widget.frameSize;

  int get max => widget.max;

  Widget redFrame(int c) => Frame.redCounters(c, frameSize);

  Widget whiteFrame(int c) => Frame.whiteCounters(c, frameSize);

  Widget frame(List<Widget> cells) => Frame(cells);
}

class _NumberMatchGameState extends _FrameGameStateBase<NumberMatchGame, _Match> {
  @override
  void initState() {
    super.initState();

    final rnd = Random();
    matches = [for (int i = widget.min; i <= widget.max; i += widget.step) _Match(i, rnd)];
  }
}

class _DoubleMatchGameState extends _FrameGameStateBase<DoubleMatchGame, _Match> {
  @override
  void initState() {
    super.initState();

    final rnd = Random();
    matches = [for (int i = widget.min; i <= widget.max / 2; i += widget.step) _DoubleMatch(i, rnd)];
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

class Frame extends StatelessWidget {
  final List<Widget> cells;

  Frame(this.cells);

  factory Frame.redCounters(int c, int size) => Frame.counters(c, size, Counter.red());

  factory Frame.whiteCounters(int c, int size) => Frame.counters(c, size, Counter.white());

  factory Frame.counters(int c, int size, Widget counter) =>
      Frame([for (int x = 0; x < min(size, c); x++) counter, for (int x = max(0, c); x < size; x++) Container()]);

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
