//
//  TgoTrackRenderer.swift
//  TgoRTCIOS
//
//  Created by Cursor on 2026/1/18.
//

import SwiftUI
import LiveKit

public struct TgoTrackRenderer: View {
    @ObservedObject var participant: TgoParticipant
    var source: Track.Source
    var fit: VideoView.LayoutMode
    
    public init(participant: TgoParticipant, source: Track.Source = .camera, fit: VideoView.LayoutMode = .fill) {
        self.participant = participant
        self.source = source
        self.fit = fit
    }
    
    public var body: some View {
        if let track = participant.getVideoTrack(source: source) {
            SwiftUIVideoView(track, layoutMode: fit, mirrorMode: TgoRTC.shared.options?.mirror == true ? .mirror : .auto)
        } else {
            Rectangle()
                .fill(Color.black)
        }
    }
}

// Extension to make TgoParticipant ObservableObject if needed, 
// but since we want to keep it as a class, we might need a wrapper or use @State
// Actually, TgoParticipant is a class, so @ObservedObject works if it conforms to ObservableObject.
// Let's make TgoParticipant conform to ObservableObject and use @Published for key properties.
