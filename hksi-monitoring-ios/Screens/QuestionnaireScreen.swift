//
//  QuestionnaireScreen.swift
//  hksi-monitoring-ios
//
//  Created by chen qiaoyi on 12/3/2025.

import SwiftUI

struct QuestionnaireScreen: View {
//    @Environment(RouteModel.self) var routeModel
    @Environment(RouteModel.self) var routeModel: RouteModel
    
    // 添加 WebRTCModel 环境对象
    @Environment(WebRTCModel.self) var webRTCModel: WebRTCModel
    
    @State private var selectedAnswers: [String: Int] = [:]
    
    // 添加状态控制弹窗
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private func submitQuestions() {
//        // 1. 检查连接状态
//        guard webRTCModelSend.connected else {
//            showAlert(message: "请先确保网络连接正常")
//            return
//        }
        
//        // 2. 验证数据有效性
//        guard selectedAnswers.values.allSatisfy({ (1...5).contains($0) }) else {
//            showAlert(message: "请选择1-5之间的有效值")
//            return
//        }
        
        // 3. 执行数据发送
        do {
            webRTCModel.sendSurveyData(surveyResult: selectedAnswers)
        } catch {
            logger.error("Failed to submit data")
        }
    }
    
    // 定义问题和选项
    let questions = [
        ("Mood State", "How would you describe your mood today?", "Highly annoyed/irritable/down", "Very positive mood"),
        ("Sleep Quality", "How well did you sleep last night?", "Hardly slept at all", "Had a great sleep"),
        ("Energy Levels", "How energetic do you feel this morning?", "Very lethargic - no energy at all", "Full of energy"),
        ("Muscle Soreness", "How sore are your muscles today?", "Extremely sore", "Not sore at all"),
        ("Stress", "How stressed do you feel this morning?", "Highly stressed", "Very relaxed")
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Daily Readiness To Train Questionnaire")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 10)
            
            ScrollView {
                ForEach(0..<questions.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(questions[index].0)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.navy)
                        Text(questions[index].1)
                            .font(.system(size: 18))
                        
                       Spacer().frame(height: 1)
//                       Spacer().frame(height: 2)
                        
                        HStack {
                            Text(questions[index].2)
//                                .font(.caption)
                                .font(.system(size: 18))
                                .foregroundStyle(.gray)
//                            Spacer()
//                            HStack(spacing: 15) {
//                                ForEach(1...5, id: \.self) { value in
//                                    RadioButton(
//                                        label: "\(value)",
//                                        isSelected: selectedAnswers[questions[index].0] == value
//                                    ) {
//                                        selectedAnswers[questions[index].0] = value
//                                    }
//                                }
//                            }
                            Spacer()
                            Text(questions[index].3)
//                                .font(.caption)
                                .font(.system(size: 18))
                                .foregroundStyle(.gray)
                        }
                        
                        
                        .overlay(
                            
                            // 扁平的长方形按钮
                            
                            HStack(spacing: 10) {
//                                Spacer().frame(height: 2)
                                
                                ForEach(1...5, id: \.self) { value in
                                    
                                    Button(action: {
                                        selectedAnswers[questions[index].0] = value
                                    }) {
                                        Text("\(value)")
                                            .font(.system(size: 18, weight: .bold))
                                            .frame(width: 110, height: 30) // 调整按钮大小
                                            .background(selectedAnswers[questions[index].0] == value ?
                                                Color(red: 0.4, green: 0.5, blue: 0.7) : // 选中状态的蓝灰色
                                                Color(red: 0.7, green: 0.75, blue: 0.85) // 未选中状态的浅蓝灰色
                                            )
//                                            .background(selectedAnswers[questions[index].0] == value ? Color.blue.opacity(0.9) : Color.blue.opacity(0.3)) // 选中和未选中的颜色
                                            .foregroundColor(.white)
                                            .cornerRadius(8) // 设置圆角
                                    }
                                    Spacer().frame(width: 25)
                                    

                                }
                            }
                            .padding(.bottom, 10) // 让按钮组下方有空隙
                    
                            
                            
//                            HStack(spacing: 30) {
//                                ForEach(1...5, id: \.self) { value in
//                                    RadioButton(
//                                        label: "\(value)",
//                                        isSelected: selectedAnswers[questions[index].0] == value
//                                    ) {
//                                        selectedAnswers[questions[index].0] = value
//                                    }
//                                }
//                            }
//                            .padding(.bottom, 25) // 添加底部间距
                        )
                        
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
            
//            Button("Submit") {
//                // 提交逻辑
//                logger.debug("Submitted answers of questionnaire")
//                routeModel.pop()
//            }
            
            Button("Submit") {
  
                // 检查是否所有问题都已回答
                let allAnswered = questions.allSatisfy { question in
                    selectedAnswers[question.0] != nil
                }
                
                guard allAnswered else {
                    alertMessage = "Please answer all questions on the questionnaire before submitting."
                    showAlert = true
                    return
                }
                
                submitQuestions()
                logger.debug("Submitted answers of questionnaire")
                routeModel.pop()
                
            }
            .alert("Attention", isPresented: $showAlert) {
                Button("Close", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            
            .buttonStyle(NavyRoundedButtonStyle())
            .padding()
        }
        .navigationTitle("Questionnaire")
        .navigationBarBackButtonHidden(true)
        
    }
    
}

// 自定义单选按钮组件
struct RadioButton: View {
    let label: String
    var isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .frame(width: 40, height: 40)
                .background(isSelected ? .navy : .white)
                .foregroundStyle(isSelected ? .white : .navy)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(.navy, lineWidth: 2)
                )
        }
    }
}

// 按钮样式
struct NavyRoundedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? .navy.opacity(0.8) : .navy)
            .cornerRadius(50)
            .padding(.horizontal)
    }
}

//#Preview {
//    QuestionnaireScreen()
//        .environment(RouteModel())
//}
