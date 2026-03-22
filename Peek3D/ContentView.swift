import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Peek3D")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Preview 3D printing files directly in Finder")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()
                .frame(maxWidth: 300)

            VStack(alignment: .leading, spacing: 12) {
                instructionRow("1", "Select a .stl, .obj, or .3mf file in Finder")
                instructionRow("2", "Press Space to preview")
                instructionRow("3", "Drag to rotate, scroll to zoom")
            }
            .padding()

            Text("Supported formats: STL, OBJ, 3MF")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }

    private func instructionRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            Text(text)
                .font(.body)
        }
    }
}
