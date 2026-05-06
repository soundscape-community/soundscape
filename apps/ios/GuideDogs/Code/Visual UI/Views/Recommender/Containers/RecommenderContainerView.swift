//
//  RecommenderContainerView.swift
//  Soundscape
//
//  Copyright (c) Microsoft Corporation.
//  Copyright (c) Soundscape Community Contributors.
//  Licensed under the MIT License.
//

import SwiftUI

struct RecommenderContainerView<Content: View>: View {
    
    // MARK: Properties
    
    let combinesAccessibilityChildren: Bool
    let content: () -> Content
    
    // MARK: Initialization
    
    init(combinesAccessibilityChildren: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.combinesAccessibilityChildren = combinesAccessibilityChildren
        self.content = content
    }
    
    // MARK: `body`
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12.0) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .accessibilityHidden(true)
                GDLocalizedTextView("recommender.view.title")
                    .accessibleTextFormat()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(Color.primaryForeground)
            .font(.footnote)
            
            content()
        }
        .padding(.horizontal, 18.0)
        .padding(.vertical, 12.0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .linearGradientBackground(.blue)
        .accessibilityElement(children: combinesAccessibilityChildren ? .combine : .contain)
    }
    
}

struct RecommenderContainerView_Previews: PreviewProvider {
    
    private static let route = RouteDetailsView_Previews.testOMRoute
    
    static var previews: some View {
        RecommenderContainerView {
            Text("This is a recommendation!")
                .foregroundColor(Color.primaryForeground)
                .font(.body)
        }
    }
}
