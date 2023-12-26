//
//  ContentView.swift
//  Reckon2
//
//  Created by Sean Cavalieri on 11/16/23.
//

import SwiftUI
import ARKit
import RealityKit

struct ContentView : View {
    @StateObject var dataModel = DataModel()
    
    var body: some View {
        ZStack {
            ARViewContainer().edgesIgnoringSafeArea(.all).environmentObject(dataModel)
            HStack {
                VStack {
                    Spacer()
                    Menu {
                        Button("Cube") {
                            dataModel.showModel(idx: 0)
                        }
                        Button("Sphere") {
                            dataModel.showModel(idx: 1)
                        }
                        Button("Cone") {
                            dataModel.showModel(idx: 2)
                        }
                    } label: {
                        Image(systemName: "plus.app").font(.system(size: 40))
                    }.padding(20)
                }
                Spacer()
                VStack {
                    Image(systemName: "arrow.clockwise").onTapGesture {
                        dataModel.hideAll()
                    }.font(.system(size: 40)).padding(20)
                    Spacer()
                    VStack {
                        Image(systemName: "arrow.up").onTapGesture {
                            dataModel.updateSurface(0.1)
                        }
                        .font(.system(size: 40))
                        .padding([.trailing], 20)
                        .padding([.bottom], 7)
                        Image(systemName: "square").onTapGesture {
                            dataModel.updateSurface(0)
                        }
                        .font(.system(size: 40))
                        .padding([.trailing], 20)
                        Image(systemName: "arrow.down").onTapGesture {
                            dataModel.updateSurface(-0.1)
                        }
                        .font(.system(size: 40))
                        .padding([.trailing, .bottom], 20)
                        .padding([.top], 7)
                    }
                }
            }
            .foregroundColor(Color(red: 207/255, green: 54/255, blue: 49/255))
        }
    }
}

struct ARViewContainer: UIViewRepresentable {
    @EnvironmentObject var dataModel: DataModel
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = dataModel.arView
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
