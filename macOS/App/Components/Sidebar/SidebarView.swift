//
//  SidebarView.swift
//  Graphnote (macOS)
//
//  Created by Hayden Pennington on 3/19/23.
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedDocument: DocumentIdentifier
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: Spacing.spacing7.rawValue)
            TreeView(selectedDocument: $selectedDocument)
                .padding()
            Spacer()
            WorkspaceMenu()
                .padding(Spacing.spacing3.rawValue)
        }
    }
}

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(selectedDocument: .constant(DocumentIdentifier(workspaceId: UUID(), documentId: UUID())))
    }
}
