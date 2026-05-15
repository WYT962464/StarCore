import UIKit
import Photos

// MARK: - 图片选择助手
// 支持相册选择和拍照，图片压缩后可发送给多模态API
class ImagePickerHelper: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private weak var viewController: UIViewController?
    private var onImagePicked: ((UIImage, Data) -> Void)?

    /// 显示图片选择器（相册+拍照）
    static func showPicker(
        from viewController: UIViewController,
        onImagePicked: @escaping (UIImage, Data) -> Void
    ) {
        let helper = ImagePickerHelper()
        helper.viewController = viewController
        helper.onImagePicked = onImagePicked

        // 保持强引用直到选择完成
        objc_setAssociatedObject(viewController, "ImagePickerHelper", helper, .OBJC_ASSOCIATION_RETAIN)

        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // 相册
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            alert.addAction(UIAlertAction(title: "📷 从相册选择", style: .default) { _ in
                helper.showImagePicker(sourceType: .photoLibrary)
            })
        }

        // 拍照
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "📸 拍照", style: .default) { _ in
                helper.showImagePicker(sourceType: .camera)
            })
        }

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.maxY - 100, width: 0, height: 0)
        }

        viewController.present(alert, animated: true)
    }

    private func showImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard let vc = viewController else { return }
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = false
        vc.present(picker, animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // 压缩图片
                let (compressed, jpegData) = self.compressImage(image)
                self.onImagePicked?(compressed, jpegData)
            }

            // 清理关联对象
            if let vc = self.viewController {
                objc_setAssociatedObject(vc, "ImagePickerHelper", nil, .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            if let vc = self?.viewController {
                objc_setAssociatedObject(vc, "ImagePickerHelper", nil, .OBJC_ASSOCIATION_RETAIN)
            }
        }
    }

    // MARK: - 图片压缩

    /// 将图片压缩到适合API发送的大小（最大1024px，JPEG质量0.6）
    private func compressImage(_ image: UIImage) -> (UIImage, Data) {
        let maxDimension: CGFloat = 1024
        var compressed = image

        // 缩放到最大边不超过maxDimension
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            if let resized = UIGraphicsGetImageFromCurrentImageContext() {
                compressed = resized
            }
            UIGraphicsEndImageContext()
        }

        // JPEG压缩
        var quality: CGFloat = 0.7
        var data = compressed.jpegData(compressionQuality: quality) ?? Data()

        // 如果还是太大（>500KB），继续降低质量
        while data.count > 500 * 1024 && quality > 0.1 {
            quality -= 0.1
            if let newData = compressed.jpegData(compressionQuality: quality) {
                data = newData
            } else {
                break
            }
        }

        return (compressed, data)
    }

    // MARK: - Base64编码

    /// 将图片数据编码为base64字符串（用于多模态API）
    static func imageToBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }

    /// 构建多模态消息格式（OpenAI vision格式）
    static func buildVisionMessage(text: String, imageData: Data) -> [String: Any] {
        let base64 = imageData.base64EncodedString()
        return [
            "role": "user",
            "content": [
                ["type": "text", "text": text],
                [
                    "type": "image_url",
                    "image_url": [
                        "url": "data:image/jpeg;base64,\(base64)"
                    ]
                ]
            ]
        ]
    }
}
