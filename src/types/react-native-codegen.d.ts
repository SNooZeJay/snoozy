declare module 'react-native/Libraries/Types/CodegenTypes' {
  // RN 0.88 ships this module as JavaScript only. RNTP's source imports the
  // codegen alias for TurboModule payloads. Keep the shim permissive so the
  // package's own generated interfaces stay usable.
  export type UnsafeObject = any;
}
