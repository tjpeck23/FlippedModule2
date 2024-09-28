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
        musicData = Array.init(repeating: 0.0, count: 20)
    }
    
    
    // public function for starting processing of microphone data
    /*func startMicrophoneProcessing(withFps:Double){
        //self.audioManager?.inputBlock = self.handleMicrophone
        
        // repeat this fps times per second using the timer class
        Timer.scheduledTimer(timeInterval: 1.0/withFps, target: self,
                            selector: #selector(self.runEveryInterval),
                            userInfo: nil,
                            repeats: true)
    }*/
    
    
    // public function for playing from a file reader file
    func startProcesingAudioFileForPlayback(){
        guard let audioManager = self.audioManager else {
                print("AudioManager is not initialized")
                return
            }
            
            guard let fileReader = self.fileReader else {
                print("FileReader is not initialized")
                return
            }
        
        // Set the output block for speaker
        audioManager.outputBlock = self.handleSpeakerQueryWithAudioFile
            
        // Play the audio file
        fileReader.play()
        print("Audio playback started")
    }
    
    //adding this to allow the equalizer to start with music and not microphone
    func startEqualizerWithAudioFile() {
        // Start processing the audio file
        startProcesingAudioFileForPlayback()
        
        // Start updating the equalizer at 60fps
        Timer.scheduledTimer(timeInterval: 1.0/60.0, target: self,
                             selector: #selector(runEveryInterval),
                             userInfo: nil,
                             repeats: true)
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
    func play() {
        self.audioManager?.play()
    }
    
    func pause(){
        self.audioManager?.pause()
    }
    
    // Here is an example function for getting the maximum frequency
    func getMaxFrequencyMagnitude() -> (Float,Float){
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
    }
    // for sliding max windows, you might be interested in the following: vDSP_vswmax
    
    // Christian: Max Frequency implementation with vDSP_vswmax
    func getMaxFrequencyMagnitudeArray() -> Array<Float>{
        
        let windowLength = vDSP_Length(fftData.count / 20)
        let outputCount = vDSP_Length(musicData.count)
        let stride = vDSP_Stride(1)
        vDSP_vswmax(fftData, stride, &musicData, stride, outputCount, windowLength)
        return musicData
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
    private func runEveryInterval() {
        if outputBuffer != nil {
                // Fetch audio data from the output buffer
                self.outputBuffer!.fetchFreshData(&timeData, withNumSamples: Int64(BUFFER_SIZE))

                // Perform FFT and update the equalizer
                fftHelper!.performForwardFFT(withData: &timeData, andCopydBMagnitudeToBuffer: &fftData)
                musicData = getMaxFrequencyMagnitudeArray()
                updateEqualizerVisualization(musicData)
        }
    }
    
    //updates equalizer to current music data
    func updateEqualizerVisualization(_ data: [Float]) {
        for i in 0..<data.count {
            print("Equalizer Band \(i): Amplitude \(data[i])")
            // Update the UI for each frequency band here
        }
    }
    
    
   
    
    //==========================================
    // MARK: Audiocard Callbacks
    // in obj-C it was (^InputBlock)(float *data, UInt32 numFrames, UInt32 numChannels)
    // and in swift this translates to:
    
    /*private func handleMicrophone (data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32) {
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
    }*/
    
    private func handleSpeakerQueryWithAudioFile(data:Optional<UnsafeMutablePointer<Float>>, numFrames:UInt32, numChannels: UInt32){
        guard let file = self.fileReader else { return }
        if let file = self.fileReader{
            
            // read from file, loaidng into data (a float pointer)
            file.retrieveFreshAudio(data,
                                    numFrames: numFrames,
                                    numChannels: numChannels)
            
            // set samples to output speaker buffer
            self.outputBuffer?.addNewFloatData(data, withNumSamples: Int64(numFrames))
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
