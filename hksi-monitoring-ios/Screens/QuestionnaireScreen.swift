//
//  QuestionnaireScreen.swift
//  hksi-monitoring-ios
//
//  Created by chen qiaoyi on 12/3/2025.

import SwiftUI

struct QuestionnaireScreen: View {
//    @Environment(RouteModel.self) var routeModel
    @Environment(RouteModel.self) var routeModel: RouteModel
    @Environment(QNScaleModel.self) var qnScaleModel: QNScaleModel
    
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
                .font(.system(size: 22, weight: .bold))
                .padding(.bottom, 5)
            
            ScrollView {
                ForEach(0..<questions.count, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(questions[index].0)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.navy)

                        Text(questions[index].1)
                            .font(.system(size: 20))
                        
                        HStack(alignment: .center, spacing: 12) {
                            // 左描述 - 固定宽度
                            Text(questions[index].2)
                                .font(.system(size: 18))
                                .foregroundStyle(Color(.darkGray).opacity(0.9))
                                .frame(width: 300, alignment: .trailing) // ✅ 固定宽度靠右对齐
                                .padding(.trailing, 6)

                            // 按钮组
                            HStack(spacing: 12) {
                                ForEach(1...5, id: \.self) { value in
                                    Button(action: {
                                        selectedAnswers[questions[index].0] = value
                                    }) {
                                        Text("\(value)")
                                            .font(.system(size: 18, weight: .bold))
                                            .frame(width: 100, height: 30)
                                            .background(
                                                selectedAnswers[questions[index].0] == value ?
                                                Color(red: 0.4, green: 0.5, blue: 0.7) :
                                                Color(red: 0.7, green: 0.75, blue: 0.85)
                                            )
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                    }
                                }
                            }

                            // 右描述 - 固定宽度
                            Text(questions[index].3)
                                .font(.system(size: 18))
                                .foregroundStyle(Color(.darkGray).opacity(0.9))
                                .frame(width: 300, alignment: .leading) // ✅ 固定宽度靠左对齐
                                .padding(.leading, 6)
                        }
                        .frame(maxWidth: .infinity, alignment: .center) // ✅ 整行居中

                        
//                        HStack(alignment: .center, spacing: 12) {
//                            // 左描述
//                            Text(questions[index].2)
//                                .font(.system(size: 18))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.trailing, 6)
//
//                            // 按钮组
//                            HStack(spacing: 12) {
//                                ForEach(1...5, id: \.self) { value in
//                                    Button(action: {
//                                        selectedAnswers[questions[index].0] = value
//                                    }) {
//                                        Text("\(value)")
//                                            .font(.system(size: 18, weight: .bold))
//                                            .frame(width: 100, height: 30)
//                                            .background(
//                                                selectedAnswers[questions[index].0] == value ?
//                                                Color(red: 0.4, green: 0.5, blue: 0.7) :
//                                                Color(red: 0.7, green: 0.75, blue: 0.85)
//                                            )
//                                            .foregroundColor(.white)
//                                            .cornerRadius(8)
//                                    }
//                                }
//                            }
//
//                            // 右描述
//                            Text(questions[index].3)
//                                .font(.system(size: 18))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.leading, 6)
//                        }
//                        .frame(maxWidth: .infinity, alignment: .center)  // ✅ 让这个整体居中


//                        HStack(alignment: .center, spacing: 12) {
//                            Text(questions[index].2)
//                                .font(.system(size: 16))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.trailing, 6)
//
//                            Spacer()
//
//                            HStack(spacing: 12) {
//                                ForEach(1...5, id: \.self) { value in
//                                    Button(action: {
//                                        selectedAnswers[questions[index].0] = value
//                                    }) {
//                                        Text("\(value)")
//                                            .font(.system(size: 18, weight: .bold))
//                                            .frame(width: 100, height: 30)
//                                            .background(
//                                                selectedAnswers[questions[index].0] == value ?
//                                                Color(red: 0.4, green: 0.5, blue: 0.7) :
//                                                Color(red: 0.7, green: 0.75, blue: 0.85)
//                                            )
//                                            .foregroundColor(.white)
//                                            .cornerRadius(8)
//                                    }
//                                }
//                            }
//
//                            Spacer()
//
//                            Text(questions[index].3)
//                                .font(.system(size: 16))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.leading, 6)
//                        }
//                        .padding(.vertical, 2)
                    }
                    .padding()
                    .frame(maxWidth: 1300, alignment: .leading)         // ✅ 卡片统一宽度 + 内容靠左
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity, alignment: .center)    // ✅ 居中显示卡片
                    .padding(.bottom, 10)

//                    VStack(alignment: .leading, spacing: 8) {
//                        Text(questions[index].0)
//                            .font(.system(size: 20, weight: .semibold))
//                            .foregroundStyle(.navy)
//                        Text(questions[index].1)
//                            .font(.system(size: 18))
//                        
////                       Spacer().frame(height: 1)
////                       Spacer().frame(height: 2)
//                   
//                        
//                        HStack(alignment: .center, spacing: 12) {
//                            
//                            // 左侧描述 - 向按钮靠拢
//                            Text(questions[index].2)
//                                .font(.system(size: 16))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.trailing, 6)
//                            
//                            // 按钮组 - 居中显示
//                            HStack(spacing: 12) {
//                                ForEach(1...5, id: \.self) { value in
//                                    Button(action: {
//                                        selectedAnswers[questions[index].0] = value
//                                    }) {
//                                        Text("\(value)")
//                                            .font(.system(size: 18, weight: .bold))
//                                            .frame(width: 100, height: 30)
//                                            .background(
//                                                selectedAnswers[questions[index].0] == value ?
//                                                Color(red: 0.4, green: 0.5, blue: 0.7) :
//                                                Color(red: 0.7, green: 0.75, blue: 0.85)
//                                            )
//                                            .foregroundColor(.white)
//                                            .cornerRadius(8)
//                                    }
//                                }
//                            }
//                            
//                            // 右侧描述 - 向按钮靠拢
//                            Text(questions[index].3)
//                                .font(.system(size: 16))
//                                .foregroundStyle(Color(.darkGray).opacity(0.9))
//                                .padding(.leading, 6)
//                        }
////                        .padding(.bottom, 4)
//                        .padding(.vertical, 2) // 减少上下空间
//
////                        // 原本的alignment
////                        HStack {
////                            Text(questions[index].2)
////                                .font(.system(size: 18))
////                                .foregroundStyle(Color(.darkGray).opacity(0.9))
////                            Spacer()
////                            Text(questions[index].3)
////                                .font(.system(size: 18))
////                                .foregroundStyle(Color(.darkGray).opacity(0.9))
////                        }
////
////                        .overlay(
////                            
////                            // 扁平的长方形按钮
////                            
////                            HStack(spacing: 10) {
//////                                Spacer().frame(height: 2)
////                                
////                                ForEach(1...5, id: \.self) { value in
////                                    
////                                    Button(action: {
////                                        selectedAnswers[questions[index].0] = value
////                                    }) {
////                                        Text("\(value)")
////                                            .font(.system(size: 18, weight: .bold))
////                                            .frame(width: 110, height: 30) // 调整按钮大小
////                                            .background(selectedAnswers[questions[index].0] == value ?
////                                                Color(red: 0.4, green: 0.5, blue: 0.7) : // 选中状态的蓝灰色
////                                                Color(red: 0.7, green: 0.75, blue: 0.85) // 未选中状态的浅蓝灰色
////                                            )
//////                                            .background(selectedAnswers[questions[index].0] == value ? Color.blue.opacity(0.9) : Color.blue.opacity(0.3)) // 选中和未选中的颜色
////                                            .foregroundColor(.white)
////                                            .cornerRadius(8) // 设置圆角
////                                    }
////                                    Spacer().frame(width: 25)
////                                    
////
////                                }
////                            }
////                            .padding(.bottom, 10) // 让按钮组下方有空隙
////                        )
////                    // 原本的alignment
//   
//                    }
//                    .padding()
//                    .frame(maxWidth: .infinity)          // ✅ 强制撑满父容器
//                    .background(Color(.systemGray6))
//                    .cornerRadius(10)
//                    .padding(.horizontal, 20)            // ✅ 给卡片左右留出边距
//                    .padding(.bottom, 10)
//                    
                    
                    
                    
//                    .padding(16)
//                    .background(...)
//                    .cornerRadius(12)
//                    .frame(maxWidth: .infinity)

//                    .padding()
//                    .background(Color(.systemGray6))
//                    .cornerRadius(10)
//                    .padding(.bottom, 10)
////                    .frame(maxWidth: 600)
//                    .frame(maxWidth: .infinity)

                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20) // ✅ 放在这里统一控制左右边距
//            .padding(.top, 10)
            
//            Button("Submit") {
//                // 提交逻辑
//                logger.debug("Submitted answers of questionnaire")
//                routeModel.pop()
//            }
            
            // 4.20 revise
            Button("Submit") {
                
                // 关闭键盘（关键步骤）
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

  
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
                
                webRTCModel.disconnect()  // 先不断开
//                webRTCModel.finalValue = nil
//                qnScaleModel.finalValue = nil
                
//                routeModel.pop()
//                routeModel.pushReplaceTop(.welcome)
                
                
                // 跳转到欢迎页（避免 push 时键盘还在 → 崩溃）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
//                    routeModel.pushReplaceTop(.welcome)
                    routeModel.pop() // 清空所有导航，回到首页
//                    routeModel.push(.welcome)

                }
                
            }
            .alert("Attention", isPresented: $showAlert) {
                Button("Close", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            
            .buttonStyle(NavyRoundedButtonStyle())
            .padding()
//            Button("Submit") {
//                // 关闭键盘（关键步骤）
//                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//
//                // 检查是否所有问题都已回答
//                let allAnswered = questions.allSatisfy { question in
//                    selectedAnswers[question.0] != nil
//                }
//
//                guard allAnswered else {
//                    alertMessage = "Please answer all questions on the questionnaire before submitting."
//                    showAlert = true
//                    return
//                }
//
//                submitQuestions()
//                logger.debug("Submitted answers of questionnaire")
//
//                // 🔁 延迟统一处理断开连接 & 跳转
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    webRTCModel.disconnect()
//                    webRTCModel.finalValue = nil
//                    routeModel.pushReplaceTop(.welcome)
//                }
//            }
//            .alert("Attention", isPresented: $showAlert) {
//                Button("Close", role: .cancel) { }
//            } message: {
//                Text(alertMessage)
//            }
//            .buttonStyle(NavyRoundedButtonStyle())
//            .padding()

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
