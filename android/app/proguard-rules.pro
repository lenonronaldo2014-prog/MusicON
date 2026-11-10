# NewPipeExtractor and its Rhino runtime use reflection.
# Based on https://github.com/TeamNewPipe/NewPipe/blob/dev/app/proguard-rules.pro
-keep class org.schabi.newpipe.extractor.timeago.patterns.** { *; }
-keep class org.mozilla.javascript.** { *; }
-keep class org.mozilla.classfile.ClassFileWriter { *; }
# Desktop-only JavaBeans conversion / JSR-223 providers are not used on Android.
-dontwarn java.beans.BeanDescriptor
-dontwarn java.beans.BeanInfo
-dontwarn java.beans.IntrospectionException
-dontwarn java.beans.Introspector
-dontwarn java.beans.PropertyDescriptor
-dontwarn javax.script.**
-dontwarn jdk.dynalink.**
