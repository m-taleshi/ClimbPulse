//
//  ProfileView.swift
//  ClimbPulse
//
//  Simple profile form for user demographics.
//

import SwiftUI

struct ProfileView: View {
    @AppStorage("profile_gender") private var gender: Gender = .unspecified
    @AppStorage("profile_birthdate") private var birthDate: Double = Calendar.current.date(byAdding: .year, value: -25, to: Date())?.timeIntervalSince1970 ?? Date().timeIntervalSince1970
    @AppStorage("profile_education") private var education: Education = .unspecified
    @AppStorage("profile_weight") private var weight: String = ""
    @AppStorage("profile_height") private var height: String = ""
    
    @State private var showBirthSheet = false
    @State private var showWeightSheet = false
    @State private var showHeightSheet = false
    @State private var pickerWeight: Int = 65
    @State private var pickerHeight: Int = 170
    
    private var birthDateBinding: Binding<Date> {
        Binding<Date>(
            get: { Date(timeIntervalSince1970: birthDate) },
            set: { birthDate = $0.timeIntervalSince1970 }
        )
    }
    
    private var ageText: String {
        let calendar = Calendar.current
        let years = calendar.dateComponents([.year], from: Date(timeIntervalSince1970: birthDate), to: Date()).year ?? 0
        return "\(max(years, 0)) years"
    }
    
    var body: some View {
        Form {
            Section(header: Text("Basic Info")) {
                Picker("Legal gender", selection: $gender) {
                    ForEach(Gender.allCases, id: \.self) { g in
                        Text(g.label).tag(g)
                    }
                }
                
                Button {
                    showBirthSheet = true
                } label: {
                    HStack {
                        Text("Birth month & year")
                        Spacer()
                        Text(formattedBirthDate)
                            .foregroundColor(.secondary)
                    }
                }
                
                Picker("Education", selection: $education) {
                    ForEach(Education.allCases, id: \.self) { e in
                        Text(e.label).tag(e)
                    }
                }
            }
            
            Section(header: Text("Body Metrics")) {
                Button {
                    showWeightSheet = true
                    pickerWeight = Int(weight) ?? 65
                } label: {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        Text(weight.isEmpty ? "Not set" : weight)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    showHeightSheet = true
                    pickerHeight = Int(height) ?? 170
                } label: {
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        Text(height.isEmpty ? "Not set" : height)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showBirthSheet) {
            BirthDateSheet(date: birthDateBinding) { showBirthSheet = false }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showWeightSheet) {
            NumberPickerSheet(
                title: "Weight (kg)",
                range: 40...180,
                selection: $pickerWeight,
                onDone: {
                    weight = "\(pickerWeight)"
                    showWeightSheet = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHeightSheet) {
            NumberPickerSheet(
                title: "Height (cm)",
                range: 140...220,
                selection: $pickerHeight,
                onDone: {
                    height = "\(pickerHeight)"
                    showHeightSheet = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
    
    private var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date(timeIntervalSince1970: birthDate))
    }
}

enum Gender: String, CaseIterable, Codable {
    case male, female, unspecified
    
    var label: String {
        switch self {
        case .male: return "Man"
        case .female: return "Woman"
        case .unspecified: return "Prefer not to say"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}

// MARK: - Sheets

private struct BirthDateSheet: View {
    @Binding var date: Date
    var onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select birth month & year",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                Spacer()
            }
            .navigationTitle("Birth date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                        .font(.headline)
                }
            }
        }
    }
}

private struct NumberEntrySheet: View {
    let title: String
    @Binding var value: String
    let placeholder: String
    let keyboardType: UIKeyboardType
    var onDone: () -> Void
    @FocusState private var focused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField(placeholder, text: $value)
                    .keyboardType(keyboardType)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .padding()
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focused = false
                            onDone()
                        }
                        .font(.headline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        focused = false
                        onDone()
                    }
                    .font(.headline)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    focused = true
                }
            }
        }
    }
}

private struct NumberPickerSheet: View {
    let title: String
    let range: ClosedRange<Int>
    @Binding var selection: Int
    var onDone: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selection) {
                    ForEach(Array(range), id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(maxHeight: 250)
                
                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                        .font(.headline)
                }
            }
        }
    }
}

enum Education: String, CaseIterable, Codable {
    case basic, highSchool, university, unspecified
    
    var label: String {
        switch self {
        case .basic: return "Basic"
        case .highSchool: return "High school"
        case .university: return "University"
        case .unspecified: return "Prefer not to say"
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
}

