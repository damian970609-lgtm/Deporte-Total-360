# Keep the Shizuku UserService entry class available to app_process.
-keep class com.damian.shadowkeys.input.InputUserService { public <init>(...); *; }
-keep interface com.damian.shadowkeys.input.IInputService { *; }
-keep class com.damian.shadowkeys.input.IInputService$Stub { *; }
