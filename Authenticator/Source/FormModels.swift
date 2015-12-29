//
//  FormModels.swift
//  Authenticator
//
//  Copyright (c) 2015 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import OneTimePassword

    enum TokenFormHeaderModel<Action> {
        case ButtonHeader(identity: String, viewModel: ButtonHeaderViewModel<Action>)
    }

    enum TokenFormRowModel<Action>: Identifiable {
        case TextFieldRow(identity: String, viewModel: TextFieldRowViewModel<Action>)
        case SegmentedControlRow(identity: String, viewModel: SegmentedControlRowViewModel<Action>)

        func hasSameIdentity(other: TokenFormRowModel) -> Bool {
            switch (self, other) {
            case let (.TextFieldRow(rowA), .TextFieldRow(rowB)):
                return rowA.identity == rowB.identity
            case let (.SegmentedControlRow(rowA), .SegmentedControlRow(rowB)):
                return rowA.identity == rowB.identity
            default:
                return false
            }
        }
    }

    enum TokenEntryAction {
        case Issuer(String)
        case Name(String)
        case Secret(String)
        case TokenType(Authenticator.TokenType)
        case DigitCount(Int)
        case Algorithm(Generator.Algorithm)

        case ShowAdvancedOptions
        case Cancel
        case Submit
    }
