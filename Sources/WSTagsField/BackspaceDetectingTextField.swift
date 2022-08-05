//
//  BackspaceDetectingTextField.swift
//  WSTagsField
//
//  Created by Ilya Seliverstov on 11/07/2017.
//  Copyright © 2017 Whitesmith. All rights reserved.
//

import UIKit

open class BackspaceDetectingTextField: UITextField {

  open var onDeleteBackwards: (() -> Void)?

  open override func deleteBackward() {
    onDeleteBackwards?()
    // Call super afterwards. The `text` property will return text prior to the delete.
    super.deleteBackward()
  }
}
