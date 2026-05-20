//
//  ContactPickerView.swift
//  SOSolutions
//
//  Created by Dee Hay on 5/12/26.
//

import SwiftUI
import ContactsUI

// UIViewControllerRepresentable that presents CNContactPickerViewController.
// Add this as a zero-sized .background() so it can access the UIKit view hierarchy
// without interfering with SwiftUI layout.
//
// Usage:
//   .background(ContactPickerRepresentable(isPresented: $showPicker) { number in
//       // number is already normalized to E.164
//   })

struct ContactPickerRepresentable: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (String) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }

        let picker = CNContactPickerViewController()
        // Show phone numbers as the selectable property so the user picks
        // a specific number when a contact has more than one.
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        picker.delegate = context.coordinator
        uiViewController.present(picker, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onPick: onPick)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        @Binding var isPresented: Bool
        let onPick: (String) -> Void

        init(isPresented: Binding<Bool>, onPick: @escaping (String) -> Void) {
            self._isPresented = isPresented
            self.onPick = onPick
        }

        func contactPicker(_ picker: CNContactPickerViewController,
                           didSelectContactProperty contactProperty: CNContactProperty) {
            guard let phoneNumber = contactProperty.value as? CNPhoneNumber else { return }
            let normalized = SecretsHelper.normalizeToE164(phoneNumber.stringValue)
                ?? phoneNumber.stringValue
            onPick(normalized)
            isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            isPresented = false
        }
    }
}
