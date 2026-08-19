import 'package:flutter/material.dart';

class WKTheme {
  static const midnight = Color(0xFF070B18);
    static const violet = Color(0xFF7C5CFF);
      static const cyan = Color(0xFF38D6FF);
        static const ember = Color(0xFFFF7A3D);

          static ThemeData dark(Color seed) {
              final c = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
                  return ThemeData(
                        useMaterial3: true,
                              brightness: Brightness.dark,
                                    colorScheme: c.copyWith(surface: midnight),
                                          scaffoldBackgroundColor: midnight,
                                                fontFamily: 'sans',
                                                      cardTheme: CardThemeData(elevation: 0, color: Colors.white.withValues(alpha:.075), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: BorderSide(color: Colors.white.withValues(alpha:.10)))),
                                                            inputDecorationTheme: InputDecorationThemeData(filled:true, fillColor:Colors.white.withValues(alpha:.07), border:OutlineInputBorder(borderRadius:BorderRadius.circular(20), borderSide:BorderSide.none), enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:BorderSide(color:Colors.white.withValues(alpha:.08)))),
                                                                  navigationBarTheme: NavigationBarThemeData(backgroundColor: const Color(0xFF0B1021).withValues(alpha:.96), indicatorColor: seed.withValues(alpha:.28), height:72),
                                                                      );
                                                                        }

                                                                          static ThemeData light(Color seed) {
                                                                              final c=ColorScheme.fromSeed(seedColor:seed, brightness:Brightness.light, dynamicSchemeVariant:DynamicSchemeVariant.fidelity);
                                                                                  return ThemeData(useMaterial3:true,colorScheme:c,scaffoldBackgroundColor:const Color(0xFFF5F6FC),cardTheme:CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(26))),inputDecorationTheme:InputDecorationThemeData(filled:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(20),borderSide:BorderSide.none)));
                                                                                    }
                                                                                    }
                                                                                    