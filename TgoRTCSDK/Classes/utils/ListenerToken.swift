//
//  ListenerToken.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import Foundation

public class ListenerToken {
    private var onCancel: (() -> Void)?
    
    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }
    
    public func cancel() {
        onCancel?()
        onCancel = nil
    }
    
    deinit {
        cancel()
    }
}
