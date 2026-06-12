import SwiftUI
import RealityKit
import ARKit
import Combine

// MARK: - Models
struct AirQualityData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let aqi: Int
    let pm25: Double
    let no2: Double
    let o3: Double
    let temperature: Double
    let humidity: Int
    let source: DataSource
    
    enum DataSource {
        case tempo, ground, combined
    }
    
    var aqiCategory: AQICategory {
        AQICategory.from(aqi: aqi)
    }
}

enum AQICategory {
    case good, moderate, unhealthySensitive, unhealthy, veryUnhealthy, hazardous
    
    static func from(aqi: Int) -> AQICategory {
        switch aqi {
        case 0...50: return .good
        case 51...100: return .moderate
        case 101...150: return .unhealthySensitive
        case 151...200: return .unhealthy
        case 201...300: return .veryUnhealthy
        default: return .hazardous
        }
    }
    
    var color: Color {
        switch self {
        case .good: return Color(hex: "#A8D5BA")
        case .moderate: return Color(hex: "#F9E79F")
        case .unhealthySensitive: return Color(hex: "#F8B88B")
        case .unhealthy: return Color(hex: "#F1948A")
        case .veryUnhealthy: return Color(hex: "#C39BD3")
        case .hazardous: return Color(hex: "#B03A2E")
        }
    }
    
    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .unhealthySensitive: return "Unhealthy for Sensitive Groups"
        case .unhealthy: return "Unhealthy"
        case .veryUnhealthy: return "Very Unhealthy"
        case .hazardous: return "Hazardous"
        }
    }
    
    var description: String {
        switch self {
        case .good: return "Air quality is satisfactory"
        case .moderate: return "Acceptable for most people"
        case .unhealthySensitive: return "Sensitive groups may be affected"
        case .unhealthy: return "Everyone may experience effects"
        case .veryUnhealthy: return "Health alert conditions"
        case .hazardous: return "Health warnings of emergency"
        }
    }
}

struct ForecastData: Identifiable {
    let id = UUID()
    let hour: Int
    let aqi: Int
    let icon: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
}

// MARK: - View Model
@MainActor
class AirQualityViewModel: ObservableObject {
    @Published var currentData: AirQualityData?
    @Published var forecastData: [ForecastData] = []
    @Published var historicalData: [AirQualityData] = []
    @Published var location: String = "Monterrey, MX"
    @Published var isLoading = false
    @Published var chatMessages: [ChatMessage] = []
    @Published var isTyping = false
    
    init() {
        loadMockData()
        initializeChat()
    }
    
    func loadMockData() {
        currentData = AirQualityData(
            timestamp: Date(),
            aqi: 72,
            pm25: 35.2,
            no2: 42.8,
            o3: 55.3,
            temperature: 28,
            humidity: 63,
            source: .combined
        )
        
        forecastData = (0..<24).map { hour in
            let baseAQI = 85
            let variation = Int.random(in: -15...15)
            return ForecastData(
                hour: hour,
                aqi: max(0, min(200, baseAQI + variation)),
                icon: "wind"
            )
        }
        
        historicalData = (0..<7).map { day in
            AirQualityData(
                timestamp: Calendar.current.date(byAdding: .day, value: -day, to: Date())!,
                aqi: Int.random(in: 50...120),
                pm25: Double.random(in: 20...60),
                no2: Double.random(in: 30...70),
                o3: Double.random(in: 40...80),
                temperature: Double.random(in: 20...30),
                humidity: Int.random(in: 50...80),
                source: .combined
            )
        }.reversed()
    }
    
    func initializeChat() {
        chatMessages.append(ChatMessage(
            text: "¡Hola! Soy tu asistente de calidad del aire. Puedo ayudarte con recomendaciones personalizadas sobre actividades al aire libre. ¿En qué te puedo ayudar?",
            isUser: false,
            timestamp: Date()
        ))
    }
    
    func sendMessage(_ text: String) {
        let userMessage = ChatMessage(text: text, isUser: true, timestamp: Date())
        chatMessages.append(userMessage)
        
        isTyping = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let response = self.generateAIResponse(for: text)
            let aiMessage = ChatMessage(text: response, isUser: false, timestamp: Date())
            self.chatMessages.append(aiMessage)
            self.isTyping = false
        }
    }
    
    func generateAIResponse(for prompt: String) -> String {
        let lowerPrompt = prompt.lowercased()
        
        guard let current = currentData else {
            return "Lo siento, no tengo datos actuales disponibles en este momento."
        }
        
        if lowerPrompt.contains("correr") || lowerPrompt.contains("ejercicio") || lowerPrompt.contains("deporte") {
            let bestHours = findBestHours()
            return "🏃‍♂️ Para correr con mejor calidad del aire, te recomiendo:\n\n⏰ Mejores horarios: \(bestHours.joined(separator: ", "))\n\n📊 AQI actual: \(current.aqi) (\(current.aqiCategory.label))\n\n💡 Consejo: Las primeras horas de la mañana suelen tener mejor calidad del aire en Monterrey."
        } else if lowerPrompt.contains("ventana") || lowerPrompt.contains("abrir") {
            if current.aqi < 100 {
                return "✅ Es un buen momento para abrir las ventanas. La calidad del aire es \(current.aqiCategory.label) con AQI de \(current.aqi)."
            } else {
                return "⚠️ No recomiendo abrir las ventanas ahora. El AQI está en \(current.aqi) (\(current.aqiCategory.label)). Mejor mantén las ventanas cerradas y usa purificadores de aire si los tienes."
            }
        } else if lowerPrompt.contains("salir") || lowerPrompt.contains("aire libre") {
            return "🌤️ Condiciones actuales en \(location):\n\n📊 AQI: \(current.aqi) - \(current.aqiCategory.label)\n🌡️ Temperatura: \(Int(current.temperature))°C\n💧 Humedad: \(current.humidity)%\n\n\(current.aqi < 100 ? "Es seguro salir, pero mantente hidratado." : "Considera limitar actividades intensas al aire libre.")"
        } else if lowerPrompt.contains("mañana") || lowerPrompt.contains("pronóstico") {
            return "🔮 Pronóstico para mañana:\n\nSegún los datos de TEMPO, esperamos condiciones similares con AQI entre 70-95. Las mejores horas serán de 6:00 a 9:00 AM y después de las 7:00 PM."
        } else if lowerPrompt.contains("niños") || lowerPrompt.contains("bebé") {
            if current.aqi > 100 {
                return "👶 Con el AQI actual de \(current.aqi), recomiendo limitar el tiempo al aire libre para niños pequeños. Son más sensibles a la contaminación. Considera actividades en interiores."
            } else {
                return "👶 Las condiciones son aceptables para niños (AQI: \(current.aqi)). Pueden jugar al aire libre, pero evita ejercicio muy intenso durante períodos prolongados."
            }
        } else {
            return "📊 Datos actuales de \(location):\n\n• AQI: \(current.aqi) (\(current.aqiCategory.label))\n• PM2.5: \(String(format: "%.1f", current.pm25)) µg/m³\n• NO₂: \(String(format: "%.1f", current.no2)) ppb\n• O₃: \(String(format: "%.1f", current.o3)) ppb\n\nPregúntame sobre actividades específicas para recibir recomendaciones personalizadas."
        }
    }
    
    func findBestHours() -> [String] {
        let sortedForecast = forecastData.sorted { $0.aqi < $1.aqi }
        let bestThree = sortedForecast.prefix(3)
        return bestThree.map { "\($0.hour):00h (AQI: \($0.aqi))" }
    }
}

// MARK: - Main Tab View
struct ContentView: View {
    @StateObject private var viewModel = AirQualityViewModel()
    
    var body: some View {
        TabView {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Label("Inicio", systemImage: "house.fill")
                }
            
            ARAtmosphereView(viewModel: viewModel)
                .tabItem {
                    Label("AR View", systemImage: "viewfinder.circle.fill")
                }
            
            ChatbotView(viewModel: viewModel)
                .tabItem {
                    Label("Asistente", systemImage: "message.fill")
                }
        }
        .accentColor(Color(hex: "#5DADE2"))
    }
}

// MARK: - Home View
struct HomeView: View {
    @ObservedObject var viewModel: AirQualityViewModel
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#E3F2FD"),
                    Color(hex: "#BBDEFB"),
                    Color(hex: "#90CAF9")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerView
                    
                    if let current = viewModel.currentData {
                        mainAQICard(data: current)
                        pollutantCards(data: current)
                    }
                    
                    hourlyForecastSection
                    historicalTrendSection
                    dataSourcesFooter
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
    }
    
    var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(viewModel.location)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { viewModel.loadMockData() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            Text("Air Quality Forecast")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 50)
    }
    
    func mainAQICard(data: AirQualityData) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                data.aqiCategory.color.opacity(0.3),
                                data.aqiCategory.color.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: data.aqiCategory.color.opacity(0.4), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 4) {
                    Text("\(data.aqi)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Air Quality\n Indicator")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.top, 20)
            
            VStack(spacing: 8) {
                Text(data.aqiCategory.label)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "#2C3E50"))
                
                Text(data.aqiCategory.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(hex: "#5D6D7E"))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 32) {
                weatherMetric(icon: "thermometer", value: "\(Int(data.temperature))°C", label: "Temp")
                weatherMetric(icon: "humidity", value: "\(data.humidity)%", label: "Humidity")
                weatherMetric(icon: "wind", value: "8 km/h", label: "Wind")
            }
            .padding(.vertical, 16)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
    }
    
    func weatherMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#5DADE2"))
            
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#2C3E50"))
            
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "#7F8C8D"))
        }
    }
    
    func pollutantCards(data: AirQualityData) -> some View {
        VStack(spacing: 12) {
            Text("Pollutant Levels")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                pollutantCard(name: "PM2.5\n(Particle Molecules)", value: data.pm25, unit: "µg/m³", icon: "aqi.medium")
                pollutantCard(name: "NO₂(Nitrogen Dioxide)", value: data.no2, unit: "ppb", icon: "smoke")
            }
            
            HStack(spacing: 12) {
                pollutantCard(name: "O₃(Tropospheric Ozone)", value: data.o3, unit: "ppb", icon: "sun.max")
                pollutantCard(name: "Combined", value: Double(data.aqi), unit: "AQI", icon: "chart.bar")
            }
        }
    }
    
    func pollutantCard(name: String, value: Double, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#5DADE2"))
                
                Spacer()
            }
            
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#7F8C8D"))
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", value))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(hex: "#2C3E50"))
                
                Text(unit)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "#95A5A6"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
        )
    }
    
    var hourlyForecastSection: some View {
        VStack(spacing: 12) {
            Text("24-Hour Forecast")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.forecastData.prefix(12)) { forecast in
                        hourlyForecastCard(forecast: forecast)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    func hourlyForecastCard(forecast: ForecastData) -> some View {
        VStack(spacing: 10) {
            Text("\(forecast.hour):00")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#5D6D7E"))
            
            Image(systemName: forecast.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#5DADE2"))
            
            Text("\(forecast.aqi)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AQICategory.from(aqi: forecast.aqi).color)
            
            Text("Air Quality Indicator")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(hex: "#95A5A6"))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
    
    var historicalTrendSection: some View {
        VStack(spacing: 12) {
            Text("7-Day Trend")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 0) {
                GeometryReader { geometry in
                    let maxAQI = viewModel.historicalData.map { $0.aqi }.max() ?? 100
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    Path { path in
                        for (index, data) in viewModel.historicalData.enumerated() {
                            let x = (width / CGFloat(viewModel.historicalData.count - 1)) * CGFloat(index)
                            let y = height - (CGFloat(data.aqi) / CGFloat(maxAQI)) * height
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color(hex: "#5DADE2"), lineWidth: 3)
                    
                    ForEach(Array(viewModel.historicalData.enumerated()), id: \.element.id) { index, data in
                        let x = (width / CGFloat(viewModel.historicalData.count - 1)) * CGFloat(index)
                        let y = height - (CGFloat(data.aqi) / CGFloat(maxAQI)) * height
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: "#5DADE2"), lineWidth: 2)
                            )
                            .position(x: x, y: y)
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                
                HStack(spacing: 0) {
                    ForEach(viewModel.historicalData) { data in
                        Text(dayLabel(for: data.timestamp))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(hex: "#7F8C8D"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
            )
        }
    }
    
    var dataSourcesFooter: some View {
        VStack(spacing: 8) {
            Text("Data Sources")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text("NASA TEMPO • OpenAQ • Weather API")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Last updated: \(Date(), formatter: dateFormatter)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }
    
    func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }
}

// MARK: - AR Atmosphere View
struct ARAtmosphereView: View {
    @ObservedObject var viewModel: AirQualityViewModel
    
    var body: some View {
        ZStack {
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()
            
            VStack {
                overlayHeader
                Spacer()
                overlayStats
            }
        }
    }
    
    var overlayHeader: some View {
        VStack(spacing: 8) {
            Text("AR Atmosphere View")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
            
            Text("Apunta al cielo para ver la calidad del aire")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
        }
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
    
    var overlayStats: some View {
        HStack(spacing: 16) {
            if let current = viewModel.currentData {
                statCard(title: "PM2.5", value: "\(Int(current.pm25))", color: Color(hex: "#F8B88B"))
                statCard(title: "AQI", value: "\(current.aqi)", color: current.aqiCategory.color)
                statCard(title: "O₃", value: "\(Int(current.o3))", color: Color(hex: "#5DADE2"))
                statCard(title: "Wind", value: "8\nkm/h", color: Color(hex: "#9B59B6").opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
    }
    
    func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.85))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
    }
}

struct ARViewContainer: UIViewRepresentable {
    var viewModel: AirQualityViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        arView.session.run(config)
        
        addParticles(to: arView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
    func addParticles(to arView: ARView) {
        guard let current = viewModel.currentData else { return }
        
        let mainAnchor = AnchorEntity(world: [0, 0, -1.5])
        
        let aqiSphere = createAQISphere(aqi: current.aqi, category: current.aqiCategory)
        aqiSphere.position = [0, 0.3, 0]
        mainAnchor.addChild(aqiSphere)
        
        let pm25Indicator = createPollutantIndicator(
            label: "PM2.5",
            value: String(format: "%.1f", current.pm25),
            color: .orange,
            position: [-0.4, 0.3, 0]
        )
        mainAnchor.addChild(pm25Indicator)
        
        let no2Indicator = createPollutantIndicator(
            label: "NO₂",
            value: String(format: "%.1f", current.no2),
            color: .cyan,
            position: [0.4, 0.3, 0]
        )
        mainAnchor.addChild(no2Indicator)
        /*
        let o3Indicator = createPollutantIndicator(
            label: "O₃",
            value: String(format: "%.1f", current.o3),
            color: .yellow,
            position: [0, 0.6, 0]
        )
        mainAnchor.addChild(o3Indicator)
        */
        
        
        let particleEmitter = ParticleEmitterComponent()
        let particleEntity = Entity()
        particleEntity.components.set(particleEmitter)
        particleEntity.position = [0, 0, 0]
        mainAnchor.addChild(particleEntity)
        
        addFloatingAnimation(to: aqiSphere)
        addFloatingAnimation(to: pm25Indicator, delay: 0.2)
        addFloatingAnimation(to: no2Indicator, delay: 0.4)
        //addFloatingAnimation(to: o3Indicator, delay: 0.6)
        
        arView.scene.addAnchor(mainAnchor)
    }
    
    func createAQISphere(aqi: Int, category: AQICategory) -> Entity {
        let sphere = Entity()
        let mesh = MeshResource.generateSphere(radius: 0.15)
        
        let baseColor: UIColor
        switch category {
        case .good:
            baseColor = UIColor(red: 0.66, green: 0.84, blue: 0.73, alpha: 0.8)
        case .moderate:
            baseColor = UIColor(red: 0.98, green: 0.91, blue: 0.62, alpha: 0.8)
        case .unhealthySensitive:
            baseColor = UIColor(red: 0.97, green: 0.72, blue: 0.55, alpha: 0.8)
        case .unhealthy:
            baseColor = UIColor(red: 0.95, green: 0.58, blue: 0.54, alpha: 0.8)
        case .veryUnhealthy:
            baseColor = UIColor(red: 0.77, green: 0.61, blue: 0.83, alpha: 0.8)
        case .hazardous:
            baseColor = UIColor(red: 0.69, green: 0.23, blue: 0.18, alpha: 0.8)
        }
        
        var material = UnlitMaterial()
        material.color = .init(tint: baseColor)
        
        sphere.components.set(ModelComponent(mesh: mesh, materials: [material]))
        
        return sphere
    }
    
    func createPollutantIndicator(label: String, value: String, color: UIColor, position: SIMD3<Float>) -> Entity {
        let indicator = Entity()
        
        let mesh = MeshResource.generateSphere(radius: 0.05)
        var material = UnlitMaterial()
        material.color = .init(tint: color)
        
        indicator.components.set(ModelComponent(mesh: mesh, materials: [material]))
        indicator.position = position
        
        return indicator
    }
    
    
    func addFloatingAnimation(to entity: Entity, delay: TimeInterval = 0) {
        let duration: TimeInterval = 3.0
        let height: Float = 0.05
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            var transform = entity.transform
            let originalY = transform.translation.y
            
            Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                let time = Date().timeIntervalSince1970
                let offset = Float(sin(time * 2.0 * .pi / duration)) * height
                transform.translation.y = originalY + offset
                entity.transform = transform
            }
        }
    }
}

// MARK: - Chatbot View
struct ChatbotView: View {
    @ObservedObject var viewModel: AirQualityViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#E3F2FD"),
                    Color(hex: "#BBDEFB")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                chatHeader
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.chatMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                TypingIndicator()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    }
                    .onChange(of: viewModel.chatMessages.count) { _, _ in
                        if let lastMessage = viewModel.chatMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                chatInputBar
            }
        }
    }
    
    var chatHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#5DADE2"), Color(hex: "#3498DB")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "cloud.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Asistente Ambiental")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#2C3E50"))
                    
                    Text("En línea")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "#5DADE2"))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 16)
        }
        .background(Color.white.opacity(0.95))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Escribe tu pregunta...", text: $messageText, axis: .vertical)
                .focused($isInputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.95))
                )
                .lineLimit(1...4)
                .font(.system(size: 16))
            
            Button(action: sendMessage) {
                Image(systemName: messageText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? Color(hex: "#95A5A6") : Color(hex: "#5DADE2"))
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.white.opacity(0.98)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        viewModel.sendMessage(messageText)
        messageText = ""
        isInputFocused = false
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(message.isUser ? .white : Color(hex: "#2C3E50"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                message.isUser ?
                                LinearGradient(
                                    colors: [Color(hex: "#5DADE2"), Color(hex: "#3498DB")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white, Color.white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                    )
                
                Text(message.timestamp, style: .time)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#95A5A6"))
                    .padding(.horizontal, 8)
            }
            
            if !message.isUser {
                Spacer(minLength: 50)
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animateScale = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(hex: "#95A5A6"))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animateScale ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animateScale
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 16)
        .onAppear {
            animateScale = true
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}


