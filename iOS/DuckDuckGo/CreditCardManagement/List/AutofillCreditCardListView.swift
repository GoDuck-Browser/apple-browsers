//
//  AutofillCreditCardListView.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI
import DesignResourcesKit
import BrowserServicesKit

struct AutofillCreditCardListView: View {
    
    @ObservedObject var viewModel: AutofillCreditCardListViewModel
    
    var body: some View {
        Group {
            if viewModel.creditCards.isEmpty {
                EmptyStateView()
            } else {
                List {
                    Section {
                        ForEach(viewModel.creditCards, id: \.self) { cardItem in
                            Button {
                                viewModel.cardSelected(cardItem)
                            } label: {
                                CreditCardRow(card: cardItem)
                            }
                        }
                    }
                    .listRowBackground(Color(designSystemColor: .surface))
                }
                .applyInsetGroupedListStyle()
            }
        }
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(.creditCardsAdd96)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)

            Group {
                Text(UserText.autofillCreditCardEmptyViewTitle)
                    .daxTitle3()
                    .foregroundStyle(Color(designSystemColor: .textPrimary))
                    .padding(.top, 16)

                Text(UserText.autofillCreditCardEmptyViewSubtitle)
                    .daxBodyRegular()
                    .foregroundStyle(Color.init(designSystemColor: .textSecondary))
                    .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            .lineLimit(nil)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            Rectangle().ignoresSafeArea().foregroundColor(Color(designSystemColor: .background))
        )
    }
}

private struct CreditCardRow: View {
    
    var card: CreditCardItem
    
    var body: some View {
        HStack {
            card.icon
                .padding(.trailing, 8)
                
            VStack(alignment: .leading) {
                Text(card.displayTitle)
                    .daxSubheadRegular()
                    .foregroundStyle(Color(designSystemColor: .textPrimary))
                    .lineLimit(1)
                (Text(verbatim: "••••").font(.system(.footnote, design: .monospaced))
                 + Text(verbatim: " ")
                 + Text(card.lastFourDigits)
                 + Text(card.expirationDate))
                    .daxFootnoteRegular()
                    .foregroundStyle(Color(designSystemColor: .textSecondary))
            }
            .padding(.vertical, 4)
            
            Spacer()
            
            Image(systemName: "chevron.forward")
                .font(Font.system(.footnote).weight(.bold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
    }
}

#Preview {
    AutofillCreditCardListView(viewModel: AutofillCreditCardListViewModel())
}
