/**
 * The library in ./library registers its own descriptors for View and for
 * Paragraph (<Text>) on iOS. Once this screen is mounted, it shows how many
 * shadow nodes each of them adopted.
 *
 * @format
 */

import { useEffect, useState } from 'react';
import { NativeModules, StyleSheet, Text, View } from 'react-native';

const { LibraryDescriptorsProbe } = NativeModules;

function App() {
  const [report, setReport] = useState<string | null>(null);

  useEffect(() => {
    setReport(LibraryDescriptorsProbe.report());
  }, []);

  return (
    <View style={styles.container}>
      <Text>A Text, which should be the library's Paragraph descriptor's.</Text>
      <Text>{report ?? 'waiting for the report'}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: 16,
    justifyContent: 'center',
    padding: 24,
  },
});

export default App;
