enum PhysicalCommandType {
  moveTo,
  magnetOn,
  magnetOff,
  delay,
}

class PhysicalCommand {
  final PhysicalCommandType type;
  final double? x;
  final double? y;
  final int? milliseconds;

  PhysicalCommand.moveTo({
    required this.x,
    required this.y,
  }) : type = PhysicalCommandType.moveTo,
      milliseconds = null;
  
  PhysicalCommand.magnetOn()
    : type = PhysicalCommandType.magnetOn,
      x = null,
      y = null,
      milliseconds = null;
  
  PhysicalCommand.magnetOff()
    : type = PhysicalCommandType.magnetOff,
      x = null,
      y = null,
      milliseconds = null;
  
  PhysicalCommand.delay(this.milliseconds)
    : type = PhysicalCommandType.delay,
      x = null,
      y = null;
}