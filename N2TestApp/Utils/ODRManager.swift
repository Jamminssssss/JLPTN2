import Foundation

class ODRManager {
    static let shared = ODRManager()
    
    // 현재 처리 중인 다운로드 요청을 보관
    private var currentRequest: NSBundleResourceRequest?
    
    /// ODR 리소스를 다운로드하거나 이미 있으면 즉시 완료 처리합니다.
    func downloadResource(tag: String, completion: @escaping (Bool) -> Void) {
        let request = NSBundleResourceRequest(tags: [tag])
        self.currentRequest = request
        
        // 1. 이미 기기에 다운로드되어 있는지 확인
        request.conditionallyBeginAccessingResources { resourcesAvailable in
            if resourcesAvailable {
                DispatchQueue.main.async { completion(true) }
            } else {
                // 2. 기기에 없으면 애플 서버(App Store)에서 다운로드 시작
                request.beginAccessingResources { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ ODR 다운로드 실패 [\(tag)]: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            print("✅ ODR 다운로드 성공 [\(tag)]")
                            completion(true)
                        }
                    }
                }
            }
        }
    }
    
    /// 리소스 사용이 끝났을 때 메모리에서 해제 (OS가 알아서 용량 관리하게 둠)
    func releaseResource() {
        currentRequest?.endAccessingResources()
        currentRequest = nil
    }
}
