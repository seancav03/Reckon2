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
//                    Image(systemName: "square.and.arrow.up").onTapGesture {
//                        dataModel.generateMap()
//                    }.font(.system(size: 40)).padding(20)
                    Spacer()
                    Image(systemName: "plus.app").onTapGesture {
                        dataModel.selectionMenuOpen.toggle()
                    }.font(.system(size: 40)).padding(20)
                        .sheet(isPresented: $dataModel.selectionMenuOpen, onDismiss: {
                            dataModel.generatedMapURL = nil
                        }, content: {
                            VStack {
                                ForEach(dataModel.models) { compElem in
                                    VStack {
                                        HStack {
                                            Button(compElem.name) {
                                                dataModel.showModel(id: compElem.id)
                                            }
                                            Spacer()
                                            
                                            if let ref = dataModel.referenceID, ref == compElem.id {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 20))
                                            } else {
                                                Image(systemName: "star")
                                                    .onTapGesture {
                                                        dataModel.referenceID = compElem.id
                                                    }
                                                    .font(.system(size: 20))
                                            }
                                            Image(systemName: "trash.fill")
                                                .onTapGesture {
                                                    dataModel.deleteElement(id: compElem.id)
                                                }
                                                .font(.system(size: 20))
                                        }
                                        Divider()
                                    }
                                }
                                Spacer()
                                if dataModel.generatedMapURL != nil {
                                    ShareLink(item: dataModel.generatedMapURL!) {
                                        Label("Press to Share", image: "square.and.arrow.up")
                                    }
                                } else {
                                    Text("Generate Map").onTapGesture {
                                        dataModel.generateMap()
                                        // TODO: Error handling (.alert if .generatedMapURL not set)
                                    }
                                }
                                Image(systemName: "plus.circle")
                                    .onTapGesture {
                                        dataModel.selectionMenuOpen = false
                                        dataModel.isImporting.toggle()
                                    }
                                    .font(.system(size: 30))
                                    .padding(.top, 20)
                            }
                            .padding(20)
                            .cornerRadius(20)
                            .shadow(radius: 5)
                            .padding(40)
                        })
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
        .fileImporter(isPresented: $dataModel.isImporting,
                        allowedContentTypes: [.usdz],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let files):
                files.forEach { file in
                    // gain access to the directory
                    let gotAccess = file.startAccessingSecurityScopedResource()
                    if !gotAccess { return }
                    // access the directory URL
                    dataModel.uploadModel(url: file)
                    // release access
                    file.stopAccessingSecurityScopedResource()
                }
            case .failure(let error):
                // TODO: handle error
                print(error)
            }
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
