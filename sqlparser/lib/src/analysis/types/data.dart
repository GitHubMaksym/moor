part of '../analysis.dart';

/// A type that sql expressions can have at runtime.
enum BasicType {
  nullType,
  int,
  real,
  text,
  blob,
}

class ResolvedType {
  final BasicType type;

  /// We set hints for additional information that might be useful for
  /// applications but aren't covered by just exposing a [BasicType]. See the
  /// comment on [TypeHint] for examples.
  final TypeHint hint;
  final bool nullable;

  const ResolvedType({this.type, this.hint, this.nullable = false});
  const ResolvedType.bool()
      : this(type: BasicType.int, hint: const IsBoolean());

  ResolvedType withNullable(bool nullable) {
    return ResolvedType(type: type, hint: hint, nullable: nullable);
  }

  @override
  bool operator ==(other) {
    return identical(this, other) ||
        other is ResolvedType &&
            other.type == type &&
            other.hint == hint &&
            other.nullable == nullable;
  }

  @override
  int get hashCode {
    return type.hashCode + hint.hashCode + nullable.hashCode;
  }

  @override
  String toString() {
    return 'ResolvedType($type, hint: $hint, nullable: $nullable)';
  }
}

/// Provides more precise hints than the [BasicType]. For instance, booleans are
/// stored as ints in sqlite, but it might be desirable to know whether an
/// expression will actually be a boolean, so we could set the
/// [ResolvedType.hint] to [IsBoolean].
abstract class TypeHint {
  const TypeHint();
}

/// Type hint to mark that this type will contain a boolean value.
class IsBoolean extends TypeHint {
  const IsBoolean();
}

/// Type hint to mark that this type will contain a date time value.
class IsDateTime extends TypeHint {
  const IsDateTime();
}
