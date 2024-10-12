//
//  ModuleBViewController.swift
//  AudioLabSwift
//
//  Created by Christian Melendez on 10/10/24.
//  Copyright © 2024 Eric Larson. All rights reserved.
//

import UIKit
import Metal



let AUDIO_BUFFER_SIZEB = 1024*16


class ModuleBViewController: UIViewController {
    
    let audio = AudioModel(buffer_size: AUDIO_BUFFER_SIZE)
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    var previousFrequency: Float?
    
    
    @IBOutlet weak var frequencySlider: UISlider!
    
    @IBOutlet weak var sliderLabel: UILabel!
    
    @IBOutlet weak var GestureLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sliderLabel.text = String(frequencySlider.value)
        audio.startMicrophoneProcessing(withFps: 5)
        audio.startProcessingSinewaveForPlayback(withFreq: frequencySlider.value)
        audio.play()
        let (startIdx, endIdx) = audio.getFrequencyIndices(startDb: 16500, endDb: 20500)
        
        // add in graphs for display
        graph?.addGraph(withName: "fft",
                        shouldNormalize: true,
                        numPointsInGraph: AUDIO_BUFFER_SIZE/2)
        
        graph?.addGraph(withName: "fftZoomed",
                        shouldNormalize: true,
                        numPointsInGraph: endIdx - startIdx)

        // run the loop for updating the graph peridocially
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
        Timer.scheduledTimer(timeInterval: 0.5, target: self,
            selector: #selector(self.checkDopplerEffect),
            userInfo: nil,
            repeats: true)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        audio.pause()
    }
    
    @IBAction func updateFrequencyViaSlider(_ sender: Any) {
        sliderLabel.text = String(frequencySlider.value)
    }
    
    @objc
    func updateGraph(){
        self.graph?.updateGraph(
            data: self.audio.fftData,
            forKey: "fft"
        )
        //zoomed graph calculations
        let (startIdx, endIdx) = audio.getFrequencyIndices(startDb: 16500, endDb: 20500)
        let subArray:[Float] = Array(self.audio.fftData[startIdx...endIdx])
        self.graph?.updateGraph(
            data: subArray,
            forKey: "fftZoomed")
    }
    
    @objc
    func checkDopplerEffect() {
        let (currentFrequency, _) = audio.getMaxFrequencyMagnitude2()
        
        var status = "Not gesturing"
        
        if let previous = previousFrequency {
            if currentFrequency < previous {
                status = "Gesturing towards"
            } else if currentFrequency > previous {
                status = "Gesturing away"
            }
        }
        previousFrequency = currentFrequency
        
        DispatchQueue.main.async {
            self.GestureLabel.text = status
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
