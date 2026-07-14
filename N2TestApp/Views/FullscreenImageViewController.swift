import SwiftUI
import UIKit

class FullscreenImageViewController: UIViewController, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let image: UIImage
    private let dismissAction: () -> Void

    init(image: UIImage, dismissAction: @escaping () -> Void) {
        self.image = image
        self.dismissAction = dismissAction
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupImageView()
        setupCloseButton()
        setupGestures()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // scrollView가 실제 크기를 확보한 뒤 imageView frame과 zoom 범위를 계산
        updateImageLayout()
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.backgroundColor = .black

        scrollView.delegate = self
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never   // safeArea가 contentSize를 밀지 않도록
        scrollView.backgroundColor = .black
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupImageView() {
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        // AutoLayout 제약 없이 frame으로만 제어 (UIScrollView zoom과 충돌 방지)
        scrollView.addSubview(imageView)
    }

    private func setupCloseButton() {
        // 배경에 반투명 원을 넣어 어떤 이미지 위에서도 잘 보이게
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "xmark",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        closeButton.configuration = config

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }

    // MARK: - Layout

    /// 화면 크기에 맞게 imageView의 frame과 scrollView의 contentSize를 설정하고,
    /// 이미지가 화면 중앙에 오도록 inset을 조정한다.
    private func updateImageLayout() {
        let boundsSize = scrollView.bounds.size
        guard boundsSize.width > 0, boundsSize.height > 0 else { return }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        // 이미지를 화면 안에 aspectFit으로 맞추는 크기 계산
        let widthScale  = boundsSize.width  / imageSize.width
        let heightScale = boundsSize.height / imageSize.height
        let fitScale    = min(widthScale, heightScale)
        let fittedSize  = CGSize(width: imageSize.width * fitScale,
                                 height: imageSize.height * fitScale)

        imageView.frame = CGRect(origin: .zero, size: fittedSize)
        scrollView.contentSize = fittedSize

        // 현재 zoom 배율을 반영해 최소 배율 재계산 (작은 이미지가 화면보다 작을 경우 대비)
        scrollView.minimumZoomScale = 1.0
        scrollView.zoomScale = 1.0

        centerImageInScrollView()
    }

    /// contentSize가 scrollView bounds보다 작을 때 상하/좌우 inset으로 이미지를 중앙 정렬
    private func centerImageInScrollView() {
        let boundsSize   = scrollView.bounds.size
        let contentSize  = scrollView.contentSize

        let hInset = max(0, (boundsSize.width  - contentSize.width)  / 2)
        let vInset = max(0, (boundsSize.height - contentSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(top: vInset, left: hInset,
                                               bottom: vInset, right: hInset)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // 줌 중에도 이미지가 항상 중앙에 위치하도록 inset 재조정
        centerImageInScrollView()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismissAction()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // 탭한 위치를 중심으로 최대 배율로 확대
            let location = gesture.location(in: imageView)
            let zoomRect = CGRect(
                x: location.x - (scrollView.bounds.width  / scrollView.maximumZoomScale) / 2,
                y: location.y - (scrollView.bounds.height / scrollView.maximumZoomScale) / 2,
                width:  scrollView.bounds.width  / scrollView.maximumZoomScale,
                height: scrollView.bounds.height / scrollView.maximumZoomScale
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
}

// MARK: - SwiftUI Wrapper

struct FullscreenImageView: UIViewControllerRepresentable {
    let image: UIImage
    let dismissAction: () -> Void

    func makeUIViewController(context: Context) -> FullscreenImageViewController {
        FullscreenImageViewController(image: image, dismissAction: dismissAction)
    }

    func updateUIViewController(_ uiViewController: FullscreenImageViewController, context: Context) {
        // 이미지가 바뀌는 케이스는 없으나, 필요 시 여기서 업데이트
    }
}
