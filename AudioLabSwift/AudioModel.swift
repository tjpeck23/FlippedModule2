//
//  AudioModel.swift
//  AudioLabSwift
//
//  Created by Eric Larson 
//  Copyright © 2020 Eric Larson. All rights reserved.
//

import Foundation
import Accelerate

class AudioModel {
    
    // MARK: Properties
    private var BUFFER_SIZE:Int
    var timeData:[Float]
    var fftData:[Float]
    // Christian: Added the array of size 20 for the Music Equalizer
    var musicData:[Float]
    
    // MARK: Public Methods
    init(buffer_size:Int) {
        BUFFER_SIZE = buffer_size
        // anything not lazily instatntiated should be allocated here
        timeData = Array.init(repeating: 0.0, count: BUFFER_SIZE)
        fftData = Array.init(repeating: 0.0, count: BUFFER_SIZE/2)
        // This is where the size of the array is decided.
        musicData = Array.init(repeating: 0.0, count: 8065)
    }
    
    // public function for starting processing of microphone data
    func startMicrophoneProcessing(withFps:Double){
        self.audioManager?.inputBlock = self.handleMicrophone
        
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
    }
    
    // public function for playing from a file reader file
    func startProcesingAudioFileForPlayback(){
        self.audioManager?.outputBlock = self.handleSpeakerQueryWithAudioFile
        self.fileReader?.play()
    }
    
    func startProcessingSinewaveForPlayback(withFreq:Float=330.0){
        sineFrequency = withFreq
        // Two examples are given that use either objective c or that use swift
        //   the swift code for loop is slightly slower thatn doing this in c,
        //   but the implementations are very similar
        //self.audioManager?.outputBlock = self.handleSpeakerQueryWithSinusoid // swift for loop
        self.audioManager?.setOutputBlockToPlaySineWave(sineFrequency) // c for loop
    }
    
    // You must call this when you want the audio to start being handled by our model
    func play(){
        self.audioManager?.play()
    }
    
    func pause(){
        self.audioManager?.pause()
    }
    
    
    func getMaxFrequencyMagnitude2() -> (Float,Float) {
        
        var max1: Float = -1000.0
        var max2: Float = -1000.0
        var max1Index: Int = 0
        var max2Index: Int = 0
        
        
        if inputBuffer != nil {
            //Find the 2 hills. If the values start going down then check the previous value to see if it's a max.
            for i in 0..<Int(self.musicData.count - 1){
                if(self.musicData[i + 1] < self.musicData[i] && self.musicData[i] > max2) {
                    if(i != 1 && self.musicData[i] >= self.musicData[i - 1]){
                        
                        if (self.musicData[i] > max1) {
                            max2 = max1
                            max1 = self.musicData[i]
                            continue
                        }
                        else{
                            max2 = self.musicData[i]
                        }
                    }
                }
            }
            //Grab the indices from the fftData array to find the frequencies.
            max1Index = fftData.firstIndex(of: max1) ?? 0
            max2Index = fftData.firstIndex(of: max2) ?? 0
        }
        
        var freq1: Float = 0.0
        var freq2: Float = 0.0
        
        freq1 = Float(max1Index) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        freq2 = Float(max2Index) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        //dump(self.musicData)
        
        return (freq1, freq2)
    }
    

    
    // Christian: Max Frequency implementation with vDSP_vswmax
    func getMaxFrequencyMagnitudeArray() -> Array<Float>{
        
        let windowLength = vDSP_Length(fftData.count / 64)
        let outputCount = vDSP_Length(fftData.count) - windowLength + 1
        let stride = vDSP_Stride(1)
        vDSP_vswmax(fftData, stride, &musicData, stride, outputCount, windowLength)
        return musicData
    }
    
    
    //func to get frequencies 50hz apart
    //fingers crossed this is right
    func findFrequenciesAtLeast50HzApart() -> [Float] {
        // Convert fftData indices to frequencies
        let frequencyResolution = Float(self.audioManager!.samplingRate) / Float(BUFFER_SIZE)
        var frequencies: [Float] = []
        
        // Find peaks in fftData
        let threshold: Float = -50.0
        for (index, magnitude) in fftData.enumerated() {
            if magnitude > threshold {
                let frequency = Float(index) * frequencyResolution
                // Check if this frequency is at least 50Hz apart from existing frequencies
                if frequencies.allSatisfy({ abs($0 - frequency) >= 50.0 }) {
                    frequencies.append(frequency)
                }
            }
        }
        return frequencies
    }
    
    
    //==========================================
    // MARK: Private Properties
    private lazy var audioManager:Novocaine? = {
        return Novocaine.audioManager()
    }()
    
    private lazy var fftHelper:FFTHelper? = {
        return FFTHelper.init(fftSize: Int32(BUFFER_SIZE))
    }()
    
    private lazy var outputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numOutputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    private lazy var inputBuffer:CircularBuffer? = {
        return CircularBuffer.init(numChannels: Int64(self.audioManager!.numInputChannels),
                                   andBufferSize: Int64(BUFFER_SIZE))
    }()
    
    
    //==========================================
    // MARK: Private Methods
    private lazy var fileReader:AudioFileReader? = {
        
        if let url = Bundle.main.url(forResource: "satisfaction", withExtension: "mp3"){
            var tmpFileReader:AudioFileReader? = AudioFileReader.init(audioFileURL: url,
                                                   samplingRate: Float(audioManager!.samplingRate),
                                                   numChannels: audioManager!.numOutputChannels)
            
            tmpFileReader!.currentTime = 0.0
            print("Audio file succesfully loaded for \(url)")
            return tmpFileReader
        }else{
            print("Could not initialize audio input file")
            return nil
        }
    }()
    
    //==========================================
    // MARK: Model Callback Methods
    @objc
    private func runEveryInterval(){
        if inputBuffer != nil {
            // copy data to swift array
            self.inputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))
            
            // now take FFT and display it
            fftHelper!.performForwardFFT(withData: &timeData,
                                         andCopydBMagnitudeToBuffer: &fftData)
            
            // Christian: Update the musical one
            musicData = getMaxFrequencyMagnitudeArray()
            
            //get the frequencies 50hz apart
            let detectedFrequencies = findFrequenciesAtLeast50HzApart()
            print("Detected Frequencies: \(detectedFrequencies)") //this is for debugging to make sure its right.
            
        }
    }
    
    
    //this func is to help determine between ooh and ahhh
    func getTwoLargestFrequencies() -> (Float, Float) {
            // Sort the fftData by magnitude to get the two largest peaks
            let frequencyResolution = Float(self.audioManager!.samplingRate) / Float(BUFFER_SIZE)
            
            // Find the two largest magnitudes and their corresponding frequencies
            var largestFreq1: Float = 0.0
            var largestFreq2: Float = 0.0
            var max1: Float = -Float.infinity
            var max2: Float = -Float.infinity
            
            for (index, magnitude) in fftData.enumerated() {
                if magnitude > max1 {
                    max2 = max1
                    max1 = magnitude
                    largestFreq2 = largestFreq1
                    largestFreq1 = Float(index) * frequencyResolution
                } else if magnitude > max2 {
                    max2 = magnitude
                    largestFreq2 = Float(index) * frequencyResolution
                }
            }
            
            return (largestFreq1, largestFreq2)
        }
   
    func getFrequencyIndices(startDb:Float, endDb: Float) -> (Int, Int) {
        var startIdx: Int = 0
        var endIdx: Int = 0
        
        startIdx = Int(startDb * Float(self.BUFFER_SIZE) / Float(self.audioManager!.samplingRate))
        endIdx = Int(endDb * Float(self.BUFFER_SIZE) / Float(self.audioManager!.samplingRate))
        
        
        return(startIdx, endIdx)
    }
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
//        var max:Float = 0.0
//        if let arrayData = data{
//            for i in 0..<Int(numFrames){
//                if(abs(arrayData[i])>max){
//                    max = abs(arrayData[i])
//                }
//            }
//        }
//        // can this max operation be made faster??
//        print(max)
        
        // copy samples from the microphone into circular buffer
        self.inputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
    }
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        if let file = self.fileReader{
            
            // read from file, loaidng into data (a float pointer)
            file.retrieveFreshAudio(data,
                                    numFrames: numFrames,
                                    numChannels: numChannels)
            
            // set samples to output speaker buffer
            self.outputBuffer?.addNewFloatData(data,
                                         withNumSamples: Int64(numFrames))
        }
    }
    
    //    _     _     _     _     _     _     _     _     _     _
    //   / \   / \   / \   / \   / \   / \   / \   / \   / \   /
    //  /   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/   \_/
    var sineFrequency:Float = 0.0 { // frequency in Hz (changeable by user)
        didSet{
            // if using swift for generating the sine wave: when changed, we need to update our increment
            //phaseIncrement = Float(2*Double.pi*sineFrequency/audioManager!.samplingRate)
            
            // if using objective c: this changes the frequency in the novocain block
            self.audioManager?.sineFrequency = sineFrequency
        }
    }
    private var phase:Float = 0.0
    private var phaseIncrement:Float = 0.0
    private var sineWaveRepeatMax:Float = Float(2*Double.pi)
    
    private func handleSpeakerQueryWithSinusoid(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        // while pretty fast, this loop is still not quite as fast as
        // writing the code in c, so I placed a function in Novocaine to do it for you
        // use setOutputBlockToPlaySineWave() in Novocaine
        if let arrayData = data{
            var i = 0
            while i<numFrames{
                arrayData[i] = sin(phase)
                phase += phaseIncrement
                if (phase >= sineWaveRepeatMax) { phase -= sineWaveRepeatMax }
                i+=1
            }
        }
    }
}
