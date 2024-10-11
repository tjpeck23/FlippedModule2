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
        musicData = Array.init(repeating: 0.0, count: 64)
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
    
    // Here is an example function for getting the maximum frequency
    /*func getMaxFrequencyMagnitude() -> (Float,Float){
        // this is the slow way of getting the maximum...
        // you might look into the Accelerate framework to make things more efficient
        var max:Float = -1000.0
        var maxi:Int = 0
        
        if inputBuffer != nil {
            for i in 0..<Int(fftData.count){
                if(fftData[i]>max){
                    max = fftData[i]
                    maxi = i
                }
            }
        }
        let frequency = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        return (max,frequency)
    }*/
    
    func getMaxFrequencyMagnitude2() -> (Float,Float) {
        
        var max1: Float = 0.0
        var max2: Float = 0.0
        var maxi: Int = 0
        var maxj: Int = 0
        
        if inputBuffer != nil {
            for i in 0..<Int(self.musicData.count){
                if(self.musicData[i] > max1){
                    max1 = self.musicData[i]
                    maxi = i
                }
            }
            
            for j in 0..<Int(self.musicData.count){
                if(self.musicData[j] > max2) && (j != maxi) {
                    max2 = self.musicData[j]
                    maxj = j
                }
            }
        }
        
        var freq1: Float = self.fftData[maxi]
        var freq2: Float = self.fftData[maxj]
        
        freq1 = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        freq2 = Float(maxj) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        
        return (freq1, freq2)
    }
    
    /*func getMaxFrequencyMagnitude() -> (Float,Float) {
        // this is the slow way of getting the maximum...
        // you might look into the Accelerate framework to make things more efficient
        var sortedMusicData:[Float] = self.musicData.sorted(by: >)
        var max1:Float = sortedMusicData[1]
        var max2:Float = sortedMusicData.last!
        var maxi:Int = 0
        var maxj:Int = 0
        var max:Float = -1000.0
        
        if inputBuffer != nil {
            for i in 0..<Int(self.musicData.count){
                if(self.musicData[i]>max){
                    for j in 0..<Int(fftData.count){
                        // wouldn't this equate the fft value to the magnitude value?
                        if(fftData[j] == self.musicData[i]){
                            max = fftData[j]
                            maxi = j
                            break
                        }
                    }
                }
            }
        }
        
        
        for i in 0..<Int(fftData.count){
            if(fftData[i] == max1){
                maxi = i
                continue
            }
            else if(fftData[i] == max2){
                maxj = i
            }
        }
        /*let frequencyi
         = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)
        let frequencyj = Float(maxi) / Float(BUFFER_SIZE) * Float(self.audioManager!.samplingRate)        //delete later
        dump(frequencyi)
        dump(frequencyj)
        */
        
        
        //need to edit to return 2 max frequencies
        return (max, frequency)
    }
    */
    
    // for sliding max windows, you might be interested in the following: vDSP_vswmax
    
    // Christian: Max Frequency implementation with vDSP_vswmax
    func getMaxFrequencyMagnitudeArray() -> Array<Float>{
        
        let windowLength = vDSP_Length(fftData.count / 64)
        let outputCount = vDSP_Length(musicData.count)
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
            
            // Will delete later
            getMaxFrequencyMagnitude2()
            
            //get the frequencies 50hz apart
            let detectedFrequencies = findFrequenciesAtLeast50HzApart()
            print("Detected Frequencies: \(detectedFrequencies)") //this is for debugging to make sure its right. 
            
        }
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
