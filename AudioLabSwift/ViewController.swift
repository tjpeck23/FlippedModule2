//
//  ViewController.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import UIKit
import Metal


let AUDIO_BUFFER_SIZE = 1024*4

let MUSICAL_EQUALIZER_SIZE = 20


class ViewController: UIViewController {

    
    let audio = AudioModel(buffer_size: AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "time",
                        shouldNormalize: false,
                        numPointsInGraph: AUDIO_BUFFER_SIZE)
        
        //A dding the music equalizer graph
        graph?.addGraph(withName: "musical",
                        shouldNormalize: true,
                        numPointsInGraph: MUSICAL_EQUALIZER_SIZE)
        
        // just start up the audio model here
        //audio.startMicrophoneProcessing(withFps: 10)
        audio.startProcesingAudioFileForPlayback()
        //audio.startProcessingSinewaveForPlayback(withFreq: 630.0)
        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
       
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        audio.pause()
    }
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        
        self.graph?.updateGraph(
            data: self.audio.timeData,
            forKey: "time"
        )
        
        // Need to update for the music equalizer
        
        self.graph?.updateGraph(
            data: self.audio.musicData,
            forKey: "musical")
    }
    
    

}

