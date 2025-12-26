//
//  SectionView.swift
//  SMARTOBD2
//
//  Created by kemo konteh on 9/30/23.
//

import SwiftUI

struct SectionView<Destination: View>: View {
    let title: String
    let subtitle: String
    let iconName: String
    let destination: Destination

    init(
        title: String,
        subtitle: String,
        iconName: String,
        destination: Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.destination = destination
    }

    var body: some View {
        NavigationLink {
            destination
        }label: {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                HStack {
                    Text(subtitle)
                        .lineLimit(2)
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.gray)

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(Color.cyclamen)
            .clipShape(.rect(cornerRadius: 10))
        }
    }
}

#Preview {
    SectionView(title: "hello", subtitle: "ola", iconName: "car.fill", destination: Text("hello"))
}
