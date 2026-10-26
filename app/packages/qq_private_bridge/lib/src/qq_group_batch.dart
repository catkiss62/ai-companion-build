/// Timers only consume existing pending input. They never manufacture input.
class QqGroupBatch {
  const QqGroupBatch({this.count=4,this.quiet=const Duration(seconds:15),
    this.maxWait=const Duration(seconds:60),this.burstQuiet=const Duration(seconds:2)});
  final int count;
  final Duration quiet,maxWait,burstQuiet;
  Duration? delay({required int pendingCount,required DateTime firstAt,
    required DateTime lastAt,required DateTime now,bool mentioned=false}) {
    if(pendingCount<=0) return null;
    final quietDue=lastAt.add(mentioned?const Duration(seconds:1):pendingCount>=count?burstQuiet:quiet);
    final maxDue=firstAt.add(maxWait); final due=quietDue.isBefore(maxDue)?quietDue:maxDue;
    return due.isAfter(now)?due.difference(now):Duration.zero;
  }
}
