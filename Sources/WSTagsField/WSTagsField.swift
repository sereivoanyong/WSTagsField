//
//  WSTagsField.swift
//  Whitesmith
//
//  Created by Ricardo Pereira on 12/05/16.
//  Copyright © 2016 Whitesmith. All rights reserved.
//

import UIKit

public struct WSTagAcceptOption: OptionSet {

  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let `return` = WSTagAcceptOption(rawValue: 1 << 0)
  public static let  comma   = WSTagAcceptOption(rawValue: 1 << 1)
  public static let  space   = WSTagAcceptOption(rawValue: 1 << 2)
}

@IBDesignable
open class WSTagsField: UIScrollView {

  public let textField = BackspaceDetectingTextField()

  /// Dedicated text field delegate.
  open weak var textDelegate: UITextFieldDelegate?

  /// Background color for tag view in normal (non-selected) state.
  @IBInspectable open override var tintColor: UIColor! {
    didSet {
      tagViews.forEach { $0.tintColor = tintColor }
    }
  }

  /// Text color for tag view in normal (non-selected) state.
  @IBInspectable open var textColor: UIColor? {
    didSet {
      tagViews.forEach { $0.textColor = textColor }
    }
  }

  /// Background color for tag view in normal (selected) state.
  @IBInspectable open var selectedColor: UIColor? {
    didSet {
      tagViews.forEach { $0.selectedColor = selectedColor }
    }
  }

  /// Text color for tag view in normal (selected) state.
  @IBInspectable open var selectedTextColor: UIColor? {
    didSet {
      tagViews.forEach { $0.selectedTextColor = selectedTextColor }
    }
  }

  @IBInspectable open var delimiter: String = "" {
    didSet {
      tagViews.forEach { $0.displayDelimiter = isDelimiterVisible ? delimiter : "" }
    }
  }

  @IBInspectable open var isDelimiterVisible: Bool = false {
    didSet {
      tagViews.forEach { $0.displayDelimiter = isDelimiterVisible ? delimiter : "" }
    }
  }

  /// Whether the text field should tokenize strings automatically when the keyboard is dismissed.
  @IBInspectable open var shouldTokenizeAfterResigningFirstResponder: Bool = false

  @IBInspectable open var maxHeight: CGFloat = CGFloat.infinity {
    didSet {
      tagViews.forEach { $0.displayDelimiter = isDelimiterVisible ? delimiter : "" }
    }
  }

  /// Max number of lines of tags can display in WSTagsField before its contents become scrollable. Default value is 0, which means WSTagsField always resize to fit all tags.
  @IBInspectable open var numberOfLines: Int = 0 {
    didSet {
      repositionViews()
    }
  }

  /// Whether or not the WSTagsField should become scrollable
  @IBInspectable open var enableScrolling: Bool = true

  @IBInspectable open var cornerRadius: CGFloat = 3.0 {
    didSet {
      tagViews.forEach { $0.cornerRadius = cornerRadius }
    }
  }

  @IBInspectable open var borderWidth: CGFloat = 0.0 {
    didSet {
      tagViews.forEach { $0.borderWidth = borderWidth }
    }
  }

  @IBInspectable open var borderColor: UIColor? {
    didSet {
      if let borderColor = borderColor {
        tagViews.forEach { $0.borderColor = borderColor }
      }
    }
  }

  open override var layoutMargins: UIEdgeInsets {
    didSet {
      tagViews.forEach { $0.layoutMargins = layoutMargins }
    }
  }

  @IBInspectable open var placeholder: String = "Tags" {
    didSet {
      updatePlaceholderTextVisibility()
    }
  }

  @IBInspectable open var placeholderColor: UIColor? {
    didSet {
      updatePlaceholderTextVisibility()
    }
  }

  @IBInspectable open var placeholderFont: UIFont? {
    didSet {
      updatePlaceholderTextVisibility()
    }
  }

  @IBInspectable open var placeholderAlwaysVisible: Bool = false {
    didSet {
      updatePlaceholderTextVisibility()
    }
  }

  open var font: UIFont? {
    didSet {
      textField.font = font
      tagViews.forEach { $0.font = font }
    }
  }

  open var keyboardAppearance: UIKeyboardAppearance = .default {
    didSet {
      textField.keyboardAppearance = keyboardAppearance
      tagViews.forEach {
        $0.keyboardAppearance = keyboardAppearance
      }
    }
  }

  @IBInspectable open var readOnly: Bool = false {
    didSet {
      unselectAllTagViewsAnimated()
      textField.isEnabled = !readOnly
      repositionViews()
    }
  }

  /// By default, the return key is used to create a tag in the field. You can change it, i.e., to use comma or space key instead.
  open var acceptTagOption: WSTagAcceptOption = .return

  open override var contentInset: UIEdgeInsets {
    didSet {
      repositionViews()
    }
  }

  @IBInspectable open var spaceBetweenTags: CGFloat = 2.0 {
    didSet {
      repositionViews()
    }
  }

  @IBInspectable open var spaceBetweenLines: CGFloat = 2.0 {
    didSet {
      repositionViews()
    }
  }

  open override var isFirstResponder: Bool {
    guard !super.isFirstResponder, !textField.isFirstResponder else {
      return true
    }

    for tagView in tagViews where tagView.isFirstResponder {
      return true
    }

    return false
  }

  open private(set) var tags: [WSTag] = []
  open var tagViews: [WSTagView] = []

  // MARK: - Events

  /// Called when the text field should return.
  open var onShouldAcceptTag: ((WSTagsField) -> Bool)?

  /// Called when the text field text has changed. You should update your autocompleting UI based on the text supplied.
  open var onDidChangeText: ((WSTagsField, _ text: String?) -> Void)?

  /// Called when a tag has been added. You should use this opportunity to update your local list of selected items.
  open var onDidAddTag: ((WSTagsField, _ tag: WSTag) -> Void)?

  /// Called when a tag has been removed. You should use this opportunity to update your local list of selected items.
  open var onDidRemoveTag: ((WSTagsField, _ tag: WSTag) -> Void)?

  /// Called when a tag has been selected.
  open var onDidSelectTagView: ((WSTagsField, _ tag: WSTagView) -> Void)?

  /// Called when a tag has been unselected.
  open var onDidUnselectTagView: ((WSTagsField, _ tag: WSTagView) -> Void)?

  /// Called before a tag is added to the tag list. Here you return false to discard tags you do not want to allow.
  open var onValidateTag: ((WSTag, [WSTag]) -> Bool)?

  /**
   * Called when the user attempts to press the Return key with text partially typed.
   * @return A Tag for a match (typically the first item in the matching results),
   * or nil if the text shouldn't be accepted.
   */
  open var onVerifyTag: ((WSTagsField, _ text: String) -> Bool)?

  /**
   * Called when the view has updated its own height. If you are
   * not using Autolayout, you should use this method to update the
   * frames to make sure the tag view still fits.
   */
  open var onDidChangeHeightTo: ((WSTagsField, _ height: CGFloat) -> Void)?

  // MARK: - Properties

  private var oldIntrinsicContentHeight: CGFloat = 0

  private var estimatedInitialMaxLayoutWidth: CGFloat {
    // Workaround: https://stackoverflow.com/questions/42342402/how-can-i-create-a-view-has-intrinsiccontentsize-just-like-uilabel
    // "So how the system knows the label's width so that it can calculate the height before layoutSubviews"
    // Re: "It calculates it. It asks “around” first by checking the last constraint (if there is one) for width. It asks it subviews (your custom class) for its constrains and then makes the calculations."
    // This is necessary because, while using the WSTagsField in a `UITableViewCell` with a dynamic height, the `intrinsicContentSize` is called first than the `layoutSubviews`, which leads to an unknown view width when AutoLayout is being used.
    if let superview = superview {
      var layoutWidth = superview.frame.width
      for constraint in superview.constraints where constraint.firstItem === self && constraint.secondItem === superview {
        if constraint.firstAttribute == .leading && constraint.secondAttribute == .leading {
          layoutWidth -= constraint.constant
        }
        if constraint.firstAttribute == .trailing && constraint.secondAttribute == .trailing {
          layoutWidth += constraint.constant
        }
      }
      return layoutWidth
    }
    else {
      for constraint in constraints where constraint.firstAttribute == .width {
        return constraint.constant
      }
    }

    return 200 // default estimation
  }

  open var preferredMaxLayoutWidth: CGFloat {
    return bounds.width == 0 ? estimatedInitialMaxLayoutWidth : bounds.width
  }

  open override var intrinsicContentSize: CGSize {
    return CGSize(width: frame.width, height: min(maxHeight, maxHeightBasedOnNumberOfLines, calculateContentHeight(layoutWidth: preferredMaxLayoutWidth) + contentInset.top + contentInset.bottom))
  }

  open override func sizeThatFits(_ size: CGSize) -> CGSize {
    return CGSize(width: size.width, height: calculateContentHeight(layoutWidth: size.width) + contentInset.top + contentInset.bottom)
  }

  open var suggestions: [String] = []
  open var caseSensitiveSuggestions: Bool = false

  // MARK: -

  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    commonInit()
  }

  deinit {
    if #available(iOS 13, *) {
      // Observers should be cleared when NSKeyValueObservation is deallocated.
      // Let's just keep the code for older iOS versions unmodified to make
      // sure we don't break anything.
      layerBoundsObserver = nil
    } else {
      if let observer = layerBoundsObserver {
        removeObserver(observer, forKeyPath: "layer.bounds")
        observer.invalidate()
        layerBoundsObserver = nil
      }
    }
  }

  open override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)

    guard newSuperview != nil else { return }
    tagViews.forEach { $0.setNeedsLayout() }
    repositionViews()
  }

  open override func layoutSubviews() {
    super.layoutSubviews()
    repositionViews()
  }

  /// Set corner radius of tag views
  open func setCornerRadius(to cornerRadius: CGFloat) {
    tagViews.forEach { $0.cornerRadius = cornerRadius }
  }

  /// Take the text inside of the field and make it a Tag.
  open func acceptCurrentTextAsTag() {
    if let currentText = tokenizeTextFieldText(), !isTextFieldEmpty {
      addTag(currentText)
    }
  }

  open var isEditing: Bool {
    return textField.isEditing
  }

  open func beginEditing() {
    textField.becomeFirstResponder()
    unselectAllTagViewsAnimated(false)
  }

  open func endEditing() {
    // NOTE: We used to check if .isFirstResponder and then resign first responder, but sometimes we noticed
    // that it would be the first responder, but still return isFirstResponder=NO.
    // So always attempt to resign without checking.
    textField.resignFirstResponder()
  }

  open override func reloadInputViews() {
    textField.reloadInputViews()
  }

  // MARK: - Adding / Removing Tags

  open func addTags(_ tags: [String]) {
    tags.forEach { addTag($0) }
  }

  open func addTags(_ tags: [WSTag]) {
    tags.forEach { addTag($0) }
  }

  open func addTag(_ tag: String) {
    addTag(WSTag(tag))
  }

  open func addTag(_ tag: WSTag) {
    if let onValidateTag = onValidateTag, !onValidateTag(tag, tags) {
      return
    } else if tags.contains(tag) {
      return
    }

    tags.append(tag)

    let tagView = WSTagView(tag: tag)
    tagView.font = font
    tagView.tintColor = tintColor
    tagView.textColor = textColor
    tagView.selectedColor = selectedColor
    tagView.selectedTextColor = selectedTextColor
    tagView.displayDelimiter = isDelimiterVisible ? delimiter : ""
    tagView.cornerRadius = cornerRadius
    tagView.borderWidth = borderWidth
    tagView.borderColor = borderColor
    tagView.keyboardAppearance = keyboardAppearance
    tagView.layoutMargins = layoutMargins

    tagView.onDidRequestSelection = { [unowned self] tagView in
      self.selectTagView(tagView, animated: true)
    }

    tagView.onDidRequestDelete = { [unowned self] tagView, replacementText in
      // First, refocus the text field
      self.textField.becomeFirstResponder()
      if let replacementText = replacementText, !replacementText.isEmpty {
        self.textField.text = replacementText
      }
      // Then remove the view from our data
      if let index = self.tagViews.firstIndex(of: tagView) {
        self.removeTag(at: index)
      }
    }

    tagView.onDidInputText = { [unowned self] tagView, text in
      if text == "\n" {
        self.selectNextTag()
      } else {
        self.textField.becomeFirstResponder()
        self.textField.text = text
      }
    }

    tagViews.append(tagView)
    addSubview(tagView)

    textField.text = ""
    onDidAddTag?(self, tag)

    // Clearing text programmatically doesn't call this automatically
    onTextFieldDidChange(textField)

    updatePlaceholderTextVisibility()
    repositionViews()
  }

  open func removeTag(_ tag: String) {
    removeTag(WSTag(tag))
  }

  open func removeTag(_ tag: WSTag) {
    if let index = tags.firstIndex(of: tag) {
      removeTag(at: index)
    }
  }

  open func removeTag(at index: Int) {
    if index < 0 || index >= tags.count { return }

    let tagView = tagViews[index]
    tagView.removeFromSuperview()
    tagViews.remove(at: index)

    let removedTag = tags[index]
    tags.remove(at: index)
    onDidRemoveTag?(self, removedTag)

    updatePlaceholderTextVisibility()
    repositionViews()
  }

  open func removeTags() {
    tags.enumerated().reversed().forEach { index, _ in removeTag(at: index) }
  }

  @discardableResult
  open func tokenizeTextFieldText() -> WSTag? {
    let text = textField.text?.trimmingCharacters(in: .whitespaces) ?? ""
    if !text.isEmpty && (onVerifyTag?(self, text) ?? true) {
      let tag = WSTag(text)
      addTag(tag)

      textField.text = ""
      onTextFieldDidChange(textField)

      return tag
    }
    return nil
  }

  // MARK: - Actions

  @objc open func onTextFieldDidChange(_ sender: AnyObject) {
    onDidChangeText?(self, textField.text)
  }

  // MARK: - Tag selection

  open func selectNextTag() {
    guard let selectedIndex = tagViews.firstIndex(where: { $0.isSelected }) else {
      return
    }

    let nextIndex = tagViews.index(after: selectedIndex)
    if nextIndex < tagViews.count {
      tagViews[selectedIndex].isSelected = false
      tagViews[nextIndex].isSelected = true
    } else {
      textField.becomeFirstResponder()
    }
  }

  open func selectPrevTag() {
    guard let selectedIndex = tagViews.firstIndex(where: { $0.isSelected }) else {
      return
    }

    let prevIndex = tagViews.index(before: selectedIndex)
    if prevIndex >= 0 {
      tagViews[selectedIndex].isSelected = false
      tagViews[prevIndex].isSelected = true
    }
  }

  open func selectTagView(_ tagView: WSTagView, animated: Bool = false) {
    if readOnly {
      return
    }

    if tagView.isSelected {
      tagView.onDidRequestDelete?(tagView, nil)
      return
    }

    tagView.isSelected = true
    tagViews.filter { $0 != tagView }.forEach {
      $0.isSelected = false
      onDidUnselectTagView?(self, $0)
    }

    onDidSelectTagView?(self, tagView)
  }

  open func unselectAllTagViewsAnimated(_ animated: Bool = false) {
    tagViews.forEach {
      $0.isSelected = false
      onDidUnselectTagView?(self, $0)
    }
  }

  // MARK: internal & private properties or methods

  // Reposition tag views when bounds changes.
  private var layerBoundsObserver: NSKeyValueObservation?
}

// MARK: TextField Properties

extension WSTagsField {

  public var text: String? {
    get { return textField.text }
    set { textField.text = newValue }
  }

  open var inputFieldAccessoryView: UIView? {
    get { return textField.inputAccessoryView }
    set { textField.inputAccessoryView = newValue }
  }

  var isTextFieldEmpty: Bool {
    return textField.text?.isEmpty ?? true
  }
}

// MARK: Private functions

extension WSTagsField {

  private func commonInit() {
    isScrollEnabled = false
    showsHorizontalScrollIndicator = false

    textColor = .white
    selectedColor = .gray
    selectedTextColor = .black

    clipsToBounds = true

    textField.backgroundColor = .clear
    textField.autocorrectionType = UITextAutocorrectionType.no
    textField.autocapitalizationType = UITextAutocapitalizationType.none
    textField.spellCheckingType = .no
    textField.delegate = self
    textField.font = font
    addSubview(textField)

    layerBoundsObserver = observe(\.layer.bounds, options: [.old, .new]) { [unowned self] sender, change in
      guard change.oldValue?.width != change.newValue?.width else {
        return
      }
      self.repositionViews()
    }

    textField.onDeleteBackwards = { [unowned self] in
      if self.readOnly {
        return
      }

      if self.isTextFieldEmpty, let tagView = self.tagViews.last {
        self.selectTagView(tagView, animated: true)
        self.textField.resignFirstResponder()
      }
    }

    textField.addTarget(self, action: #selector(onTextFieldDidChange(_:)), for: .editingChanged)

    repositionViews()
  }

  private func calculateContentHeight(layoutWidth: CGFloat) -> CGFloat {
    var totalRect: CGRect = .null
    enumerateItemRects(layoutWidth: layoutWidth) { _, tagRect, textFieldRect in
      if let tagRect = tagRect {
        totalRect = tagRect.union(totalRect)
      } else if let textFieldRect = textFieldRect {
        totalRect = textFieldRect.union(totalRect)
      }
    }
    return totalRect.height
  }

  private func enumerateItemRects(layoutWidth: CGFloat, using closure: (_ tagView: WSTagView?, _ tagRect: CGRect?, _ textFieldRect: CGRect?) -> Void) {
    if layoutWidth == 0 {
      return
    }

    let maxWidth: CGFloat = layoutWidth - contentInset.left - contentInset.right
    var curX: CGFloat = 0.0
    var curY: CGFloat = 0.0
    var totalHeight: CGFloat = Constants.standardRowHeight

    // Tag views Rects
    var tagRect: CGRect = .null
    for tagView in tagViews {
      tagRect = CGRect(origin: .zero, size: tagView.sizeToFit(CGSize(width: maxWidth, height: 0)))

      if curX + tagRect.width > maxWidth {
        // Need a new line
        curX = 0
        curY += Constants.standardRowHeight + spaceBetweenLines
        totalHeight += Constants.standardRowHeight
      }

      tagRect.origin.x = curX
      // Center our tagView vertically within STANDARD_ROW_HEIGHT
      tagRect.origin.y = curY + ((Constants.standardRowHeight - tagRect.height)/2.0)

      closure(tagView, tagRect, nil)

      curX = tagRect.maxX + spaceBetweenTags
    }

    // Always indent TextField by a little bit
    curX += max(0, Constants.textFieldHorizontalSpacing - spaceBetweenTags)
    var availableWidthForTextField: CGFloat = maxWidth - curX

    if textField.isEnabled {
      var textFieldRect = CGRect.zero
      textFieldRect.size.height = Constants.standardRowHeight

      if availableWidthForTextField < Constants.minimumTextFieldWidth {
        // If in the future we add more UI elements below the tags,
        // isOnFirstLine will be useful, and this calculation is important.
        // So leaving it set here, and marking the warning to ignore it
        curX = 0 + Constants.textFieldHorizontalSpacing
        curY += Constants.standardRowHeight + spaceBetweenLines
        totalHeight += Constants.standardRowHeight
        // Adjust the width
        availableWidthForTextField = maxWidth - curX
      }
      textFieldRect.origin.y = curY
      textFieldRect.origin.x = curX
      textFieldRect.size.width = availableWidthForTextField

      closure(nil, nil, textFieldRect)
    }
  }

  private func repositionViews() {
    if bounds.width == 0 {
      return
    }

    var contentRect: CGRect = .null
    enumerateItemRects(layoutWidth: bounds.width) { tagView, tagRect, textFieldRect in
      if let tagRect = tagRect, let tagView = tagView {
        tagView.frame = tagRect
        tagView.setNeedsLayout()
        contentRect = tagRect.union(contentRect)
      } else if let textFieldRect = textFieldRect {
        textField.frame = textFieldRect
        contentRect = textFieldRect.union(contentRect)
      }
    }

    textField.isHidden = !textField.isEnabled

    invalidateIntrinsicContentSize()
    let newIntrinsicContentHeight = intrinsicContentSize.height

    if constraints.isEmpty {
      frame.size.height = newIntrinsicContentHeight.rounded()
    }

    if oldIntrinsicContentHeight != newIntrinsicContentHeight {
      if let didChangeHeightToEvent = onDidChangeHeightTo {
        didChangeHeightToEvent(self, newIntrinsicContentHeight)
      }
      oldIntrinsicContentHeight = newIntrinsicContentHeight
    }

    if enableScrolling {
      isScrollEnabled = contentRect.height + contentInset.top + contentInset.bottom > newIntrinsicContentHeight
    }
    contentSize.width = bounds.width - contentInset.left - contentInset.right
    contentSize.height = contentRect.height

    if isScrollEnabled {
      // FIXME: this isn't working. Need to think in a workaround.
      // self.scrollRectToVisible(textField.frame, animated: false)
    }
  }

  private func updatePlaceholderTextVisibility() {
    textField.attributedPlaceholder = (placeholderAlwaysVisible || tags.isEmpty) ? attributedPlaceholder() : nil
  }

  private func attributedPlaceholder() -> NSAttributedString {
    var attributes: [NSAttributedString.Key: Any] = [:]
    attributes[.foregroundColor] = placeholderColor
    attributes[.font] = placeholderFont
    return NSMutableAttributedString(string: placeholder, attributes: attributes)
  }

  private var maxHeightBasedOnNumberOfLines: CGFloat {
    guard numberOfLines > 0 else {
      return .infinity
    }
    return contentInset.top + contentInset.bottom + Constants.standardRowHeight * CGFloat(numberOfLines) + spaceBetweenLines * CGFloat(numberOfLines - 1)
  }
}

extension WSTagsField: UITextFieldDelegate {

  public func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
    textDelegate?.textFieldShouldBeginEditing?(textField) ?? true
  }

  public func textFieldDidBeginEditing(_ textField: UITextField) {
    textDelegate?.textFieldDidBeginEditing?(textField)
    unselectAllTagViewsAnimated(true)
  }

  public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
    textDelegate?.textFieldShouldEndEditing?(textField) ?? true
  }

  public func textFieldDidEndEditing(_ textField: UITextField) {
    if !isTextFieldEmpty, shouldTokenizeAfterResigningFirstResponder {
      tokenizeTextFieldText()
    }
    textDelegate?.textFieldDidEndEditing?(textField)
  }

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if let onShouldAcceptTag = onShouldAcceptTag, !onShouldAcceptTag(self) {
      return false
    }
    if !isTextFieldEmpty && acceptTagOption.contains(.return) {
      tokenizeTextFieldText()
      return true
    }
    return textDelegate?.textFieldShouldReturn?(textField) ?? false
  }

  public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
    if acceptTagOption.contains(.comma) && string == "," && onShouldAcceptTag?(self) ?? true {
      tokenizeTextFieldText()
      return false
    }
    if acceptTagOption.contains(.space) && string == " " && onShouldAcceptTag?(self) ?? true {
      tokenizeTextFieldText()
      return false
    }
    return !autoCompleteText(for: textField, using: string)
  }

  private func autoCompleteText(for textField: UITextField, using string: String) -> Bool {
    guard !string.isEmpty,
          let selectedTextRange = textField.selectedTextRange,
          selectedTextRange.end == textField.endOfDocument,
          let prefixRange = textField.textRange(from: textField.beginningOfDocument, to: selectedTextRange.start),
          let text = textField.text(in: prefixRange) else { return false }

    let pfx = text + string
    let matches = suggestions.filter { caseSensitiveSuggestions ? $0.hasPrefix(pfx) : $0.range(of: pfx, options: [.anchored, .caseInsensitive]) != nil }

    if matches.count > 0 {
      textField.text = matches[0]

      if let start = textField.position(from: textField.beginningOfDocument, offset: pfx.count) {
        textField.selectedTextRange = textField.textRange(from: start, to: textField.endOfDocument)
        return true
      }
    }
    return false
  }
}

extension WSTagsField {

  public static func == (lhs: UITextField, rhs: WSTagsField) -> Bool {
    return lhs == rhs.textField
  }
}
