part of '../analysis.dart';

/// Reads the [Table] definition from a [CreateTableStatement].
class SchemaFromCreateTable {
  /// Whether we should provide additional type hints for nonstandard `BOOL`
  /// and `DATETIME` columns.
  final bool moorExtensions;

  const SchemaFromCreateTable({this.moorExtensions = false});

  Table read(TableInducingStatement stmt) {
    if (stmt is CreateTableStatement) {
      return _readCreateTable(stmt);
    } else if (stmt is CreateVirtualTableStatement) {
      final module = stmt.scope.resolve<Module>(stmt.moduleName);
      return module.parseTable(stmt);
    }

    throw AssertionError('Unknown table statement');
  }

  /// Creates a [View] from a [CreateViewStatement]. The `CREATE VIEW` statement
  /// must be fully resolved through [context] when calling this method.
  ///
  /// Example:
  /// ```dart
  /// // this will run analysis on the inner select statement and resolve columns
  /// final ctx = engine.analyze('CREATE VIEW ...');
  /// final createViewStmt = ctx.root as CreateViewStatement;
  ///
  /// final view = const SchemaFromCreateTable().readView(ctx, createViewStmt);
  /// ```
  View readView(AnalysisContext context, CreateViewStatement stmt) {
    final columnsFromSelect = stmt.query.resolvedColumns;
    final overriddenNames = stmt.columns ?? const [];

    final viewColumns = List<ViewColumn>(columnsFromSelect.length);

    for (var i = 0; i < columnsFromSelect.length; i++) {
      final column = columnsFromSelect[i];

      // overriddenNames might be shorter than the columns. That's not a valid
      // CREATE VIEW statement, but we try not to crash.
      final name = i < overriddenNames.length ? overriddenNames[i] : null;

      viewColumns[i] = ViewColumn(column, context.typeOf(column).type, name);
    }

    return View(
      name: stmt.viewName,
      resolvedColumns: viewColumns,
      definition: stmt,
    );
  }

  Table _readCreateTable(CreateTableStatement stmt) {
    return Table(
      name: stmt.tableName,
      resolvedColumns: [for (var def in stmt.columns) _readColumn(def)],
      withoutRowId: stmt.withoutRowId,
      tableConstraints: stmt.tableConstraints,
      definition: stmt,
    );
  }

  TableColumn _readColumn(ColumnDefinition definition) {
    final typeName = definition.typeName.toUpperCase();

    final type = resolveColumnType(typeName);
    final nullable = !definition.constraints.any((c) => c is NotNull);

    final resolvedType = type.withNullable(nullable);

    return TableColumn(
      definition.columnName,
      resolvedType,
      definition: definition,
    );
  }

  /// Resolves a column type via its typename, see the linked rules below.
  /// Additionally, if [moorExtensions] are enabled, we support [IsBoolean] and
  /// [IsDateTime] hints if the type name contains `BOOL` or `DATE`,
  /// respectively.
  /// https://www.sqlite.org/datatype3.html#determination_of_column_affinity
  ResolvedType resolveColumnType(String typeName) {
    if (typeName == null) {
      return const ResolvedType(type: BasicType.blob);
    }

    final upper = typeName.toUpperCase();
    if (upper.contains('INT')) {
      return const ResolvedType(type: BasicType.int);
    }
    if (upper.contains('CHAR') ||
        upper.contains('CLOB') ||
        upper.contains('TEXT')) {
      return const ResolvedType(type: BasicType.text);
    }

    if (upper.contains('BLOB')) {
      return const ResolvedType(type: BasicType.blob);
    }

    if (moorExtensions) {
      if (upper.contains('BOOL')) {
        return const ResolvedType.bool();
      }
      if (upper.contains('DATE')) {
        return const ResolvedType(type: BasicType.int, hint: IsDateTime());
      }
    }

    return const ResolvedType(type: BasicType.real);
  }

  /// Looks up the correct column affinity for a declared type name with the
  /// rules described here:
  /// https://www.sqlite.org/datatype3.html#determination_of_column_affinity
  @visibleForTesting
  BasicType columnAffinity(String typeName) => resolveColumnType(typeName).type;
}
