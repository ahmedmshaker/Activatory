import 'dart:core';
import 'dart:math';

import 'package:activatory/src/activation_context.dart';
import 'package:activatory/src/aliases/type_alias_registry.dart';
import 'package:activatory/src/backends/explicit_backend.dart';
import 'package:activatory/src/backends/singleton_backend.dart';
import 'package:activatory/src/backends_factory.dart';
import 'package:activatory/src/backends_registry.dart';
import 'package:activatory/src/customization/backend_resolver_factory.dart';
import 'package:activatory/src/customization/type_customization.dart';
import 'package:activatory/src/customization/type_customization_registry.dart';
import 'package:activatory/src/generator_delegate.dart';
import 'package:activatory/src/post_activation/fields_filler.dart';
import 'package:activatory/src/value_generator_impl.dart';

class Activatory {
  final Random _random = new Random(DateTime.now().millisecondsSinceEpoch);
  ValueGeneratorImpl _valueGenerator;
  BackendsRegistry _backendRegistry;
  TypeCustomizationRegistry _customizationsRegistry;
  BackendResolverFactory _backendResolverFactory;
  TypeAliasesRegistry _typeAliasesRegistry;

  Activatory() {
    _typeAliasesRegistry = new TypeAliasesRegistry();
    _customizationsRegistry = new TypeCustomizationRegistry();
    _backendResolverFactory = new BackendResolverFactory(_random);
    var backendFactory = new BackendsFactory(_random);
    _backendRegistry =
        new BackendsRegistry(backendFactory, _customizationsRegistry, _backendResolverFactory, _typeAliasesRegistry);
    _valueGenerator = new ValueGeneratorImpl(_backendRegistry, new FieldsFiller());
  }

  // region Activation members

  /// Creates and returns instance of specified [type] filled with random data recursively.
  /// Uses [key] to select configuration.
  T get<T>([Object key = null]) => getUntyped(T, key) as T;

  /// Creates and returns instance of specified [type] filled with random data recursively.
  /// Uses [key] to select configuration.
  Object getUntyped(Type type, [Object key = null]) {
    var context = _createContext(key);
    return _valueGenerator.create(type, context);
  }

  /// Creates and returns multiple instances of specified [type] filled with random data recursively.
  /// Returns [List] of size [count]. If [count] is not specified default strategy will be used.
  /// Uses [key] to select configuration.
  List getManyUntyped(Type type, {int count, Object key}) {
    var countToCreate = count ?? _customizationsRegistry.get(type, key: key).arraySize;
    return List.generate(countToCreate, (int index) => getUntyped(type, key));
  }

  /// Creates and returns multiple instances of specified type [T] filled with random data recursively.
  /// Returns [List] of size [count]. If [count] is not specified default strategy will be used.
  /// Uses [key] to select configuration.
  List<T> getMany<T>({int count, Object key}) {
    var dynamicResult = getManyUntyped(T, count: count, key: key);
    //Cast result from List<dynamic> to List<T> through array creation
    return new List<T>.from(dynamicResult);
  }

  /// Returns random item from iterable. [variations] value will be iterated while choosing item.
  Object takeUntyped(Iterable variations) {
    final items = variations.toList();
    final index = _random.nextInt(items.length);
    return items[index];
  }

  /// Returns random item from iterable.  [variations] value will be iterated while choosing item.
  T take<T>(Iterable<T> variations) => takeUntyped(variations) as T;

  /// Returns random items from iterable. [variations] value will be iterated while choosing item.
  List<Object> takeManyUntyped(int count, Iterable variations) => List.generate(count, (_) => takeUntyped(variations));

  /// Returns random items from iterable.  [variations] value will be iterated while choosing item.
  List<T> takeMany<T>(int count, Iterable<T> variations) => takeManyUntyped(count, variations) as List<T>;

  // endregion

  // region Customization members

  /// Registers function to be called to activate instance of type [T] with [key].
  void useFunction<T>(GeneratorDelegate<T> generator, {Object key}) {
    var backend = new ExplicitBackend<T>(generator);
    _backendRegistry.registerTyped<T>(backend, key: key);
  }

  /// Creates instance of type [T] and fixes it as a result for subsequent activation calls for type [T] with customization [key].
  ///
  /// Uses current state of customization for [key]. Subsequent customization changes will not affect fixed value.
  /// To override fixed value call this method again.
  void useGeneratedSingleton<T>({Object key}) {
    var detachedContext = _backendRegistry.clone();
    var context = _createContext(null);
    var currentBackend = detachedContext.get(T, context);
    var value = currentBackend.get(context);

    useSingleton<T>(value, key: key);
  }

  /// Fixes passed [value] as a result for subsequent activation calls for type [T] with customization [key].
  void useSingleton<T>(T value, {Object key}) {
    var backend = new SingletonBackend<T>(value);
    _backendRegistry.registerTyped<T>(backend, key: key);
  }

  /// Marks [TTarget] as replacement for [TSource] activation calls.
  ///
  /// Allows to use [TTarget] type as activation target for [TSource] activation.
  /// [TTarget] should implements [TSource].
  void replaceSupperClass<TSource, TTarget extends TSource>() => _typeAliasesRegistry.setAlias(TSource, TTarget);

  /// Returns default customization which is used to activate not customized object types.
  /// Use returned value to customize default activation options.
  TypeCustomization get defaultCustomization => _customizationsRegistry.get(null, key: null);

  /// Returns customization for specified type [T] and [key].
  /// If [key] is not specified type default configuration will be returned.
  /// Type default configuration is used while activation in next cases:
  ///  * if key is not provided as parameter for activation call;
  ///  * if key specified while activation call was not configured.
  ///  Use returned value to customize activation options for type [T] and [key] pair.
  TypeCustomization customize<T>({Object key = null}) => _customizationsRegistry.get(T, key: key);

  //endregion

  ActivationContext _createContext(Object key) =>
      new ActivationContext(_valueGenerator, _random, key, _customizationsRegistry);
}
