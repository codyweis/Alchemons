abstract class Effect {
  final String id;
  Effect(this.id);

  /// Attach to any entity object; use runtime checks if needed.
  void onAttach(Object? entity) {}
  void onDetach(Object? entity) {}
  void update(Object? entity, double dt) {}

  /// Modify a named stat. Called in order of attachment; implement stacking rules here.
  double modifyStat(String stat, double base) => base;

  Map<String, dynamic> toJson();
}
