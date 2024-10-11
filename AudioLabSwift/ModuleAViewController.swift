//
//  ModuleAViewController.swift
//  AudioLabSwift
//
//  Created by Travis Peck on 10/8/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//


import UIKit
import Metal



let AUDIO_BUFFER_SIZE = 1024*16 //was 8


let MUSICAL_EQUALIZER_SIZE = 8065


class ModuleAViewController: UIViewController {

    @IBOutlet weak var MaxFreq1: UILabel!
    
    @IBOutlet weak var MaxFreq2: UILabel!
    
    @IBOutlet weak var OOHOrAAHH: UILabel!
    
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
        audio.startMicrophoneProcessing(withFps: 5)
        //audio.startProcesingAudioFileForPlayback()
        audio.startProcessingSinewaveForPlayback(withFreq: 630.0)
        audio.play()
        
        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
        Timer.scheduledTimer(timeInterval: 0.05,
                             target: self,
                             selector: #selector (self.updateFrequencies),
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
        
        detectOOHorAAHHSound()
    }
    
    @objc
    func updateFrequencies(){
        let (freq1, freq2) = audio.getMaxFrequencyMagnitude2()
        print("Frequencies: \(freq1), \(freq2)")
        MaxFreq1.text = "Frequency 1: \(freq1)"
        MaxFreq2.text = "Frequency 2: \(freq2)"
    }
    
    func detectOOHorAAHHSound(){
        let (freq1, freq2) = audio.getTwoLargestFrequencies()
                
                // Classify the sound based on frequency ranges
                if isOoooo(f1: freq1, f2: freq2) {
                    OOHOrAAHH.text = "ooooo"
                } else if isAhhhh(f1: freq1, f2: freq2) {
                    OOHOrAAHH.text = "ahhhh"
                } else {
                    OOHOrAAHH.text = "Unknown Sound"
                }
    }
    
    //I used google to find the frequencies that ooh as in like boo or Ahh like father normally are and put then into these funcs but honeslty it was eaisr to just yell into computer myself and see what frequencys i got for ooh or aahh
    
    func isOoooo(f1: Float, f2: Float) -> Bool {
        return (f1 >= 50 && f1 <= 200) && (f2 >= 100 && f2 <= 250)
        }

    func isAhhhh(f1: Float, f2: Float) -> Bool {
        return (f1 >= 250 && f1 <= 900) && (f2 >= 400 && f2 <= 1600)
        }
    
}

