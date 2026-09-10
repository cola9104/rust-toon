//! Pixel geometry is a generation contract, independent of prompt wording.
//! Passing `2K` alone lets providers choose an unsuitable aspect ratio.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct ImageCanvas {
    pub width: u32,
    pub height: u32,
}

impl ImageCanvas {
    pub fn for_quality(quality: &str, ratio: &str) -> Result<Self, String> {
        let long_edge = match quality.trim().to_ascii_uppercase().as_str() {
            "1K" => 1280.0,
            "2K" => 2560.0,
            "4K" => 3840.0,
            _ => return Err("图片清晰度必须为 1K、2K 或 4K".into()),
        };
        let (width, height) = ratio
            .split_once(':')
            .and_then(|(w, h)| Some((w.parse::<f64>().ok()?, h.parse::<f64>().ok()?)))
            .filter(|(w, h)| w.is_finite() && h.is_finite() && *w > 0.0 && *h > 0.0)
            .ok_or_else(|| "图片比例无效，请使用例如 3:2 或 16:9".to_string())?;
        let aspect = width / height;
        if !(1.0 / 3.0..=3.0).contains(&aspect) {
            return Err("图片宽高比必须在 1:3 到 3:1 之间".into());
        }
        let align = |value: f64| ((value / 32.0).round().max(1.0) * 32.0) as u32;
        Ok(Self {
            width: align(if aspect >= 1.0 {
                long_edge
            } else {
                long_edge * aspect
            }),
            height: align(if aspect >= 1.0 {
                long_edge / aspect
            } else {
                long_edge
            }),
        })
    }

    pub fn parse(size: &str) -> Result<Self, String> {
        let (width, height) = size
            .split_once('x')
            .and_then(|(w, h)| Some((w.parse::<u32>().ok()?, h.parse::<u32>().ok()?)))
            .filter(|(w, h)| *w > 0 && *h > 0 && *w <= 8192 && *h <= 8192)
            .ok_or_else(|| "图片生成必须指定明确的像素宽高".to_string())?;
        Ok(Self { width, height })
    }

    pub fn size(self) -> String {
        format!("{}x{}", self.width, self.height)
    }

    pub fn validate_dimensions(self, width: u32, height: u32) -> Result<(), String> {
        if width == 0 || height == 0 {
            return Err("生成图片尺寸为空".into());
        }
        let expected = self.width as f64 / self.height as f64;
        let actual = width as f64 / height as f64;
        // Providers may align to a pixel grid or upscale to their minimum area.
        if (actual / expected - 1.0).abs() > 0.03 {
            return Err(format!(
                "生成图片比例不合格：要求 {}，实际 {width}x{height}；请重新生成",
                self.size()
            ));
        }
        if (width as f64) < self.width as f64 * 0.95 || (height as f64) < self.height as f64 * 0.95
        {
            return Err(format!(
                "生成图片分辨率不足：要求 {}，实际 {width}x{height}；请重新生成",
                self.size()
            ));
        }
        Ok(())
    }
}

/// Neutral-background character sheets must leave space above the hair and
/// below the shoes. A wide foreground run reaching either image edge is a
/// reproducible sign of clipping. This is not an anatomy/face detector.
pub(crate) fn validate_role_margins(image: &image::DynamicImage) -> Result<(), String> {
    use image::GenericImageView;
    let (width, height) = image.dimensions();
    if width < 100 || height < 100 {
        return Ok(());
    }
    let rows = (height / 200).clamp(2, 12);
    let has_foreground_run = |y: u32| {
        let samples = (0..16)
            .flat_map(|i| [width * i / 800, width - 1 - width * i / 800])
            .map(|x| image.get_pixel(x, y).0)
            .collect::<Vec<_>>();
        let transparent = samples.iter().all(|p| p[3] < 16);
        let mean = std::array::from_fn::<_, 3, _>(|channel| {
            samples.iter().map(|p| p[channel] as f64).sum::<f64>() / samples.len() as f64
        });
        // Complex backgrounds cannot be judged reliably by this inexpensive check.
        if !transparent
            && samples
                .iter()
                .any(|p| (0..3).any(|c| (p[c] as f64 - mean[c]).abs() > 35.0))
        {
            return false;
        }
        let mut run = 0;
        for x in width / 25..width - width / 25 {
            let p = image.get_pixel(x, y).0;
            let foreground = if transparent {
                p[3] > 128
            } else {
                p[3] > 128
                    && (0..3).map(|c| (p[c] as f64 - mean[c]).powi(2)).sum::<f64>() > 19_200.0
            };
            run = if foreground { run + 1 } else { 0 };
            if run >= width / 50 {
                return true;
            }
        }
        false
    };
    if (0..rows).filter(|y| has_foreground_run(*y)).count() >= 2
        || (height - rows..height)
            .filter(|y| has_foreground_run(*y))
            .count()
            >= 2
    {
        return Err("角色图主体疑似被裁切：人物触及画面上下边缘，未留出完整头顶或鞋底空间；请缩小人物并重新生成全身图".into());
    }
    Ok(())
}

/// An identity-free layout reference: full-height silhouettes with generous
/// top/bottom space, rather than relying only on the words "full body".
pub(crate) fn role_layout_reference(four_views: bool) -> Result<String, String> {
    use base64::Engine;
    let views = if four_views { 4 } else { 3 };
    let mut canvas = image::RgbImage::from_pixel(views * 256, 512, image::Rgb([240, 240, 240]));
    for view in 0..views {
        let center = (view * 256 + 128) as i32;
        let side = view == 1 || (four_views && view == 2);
        for y in 0..512_i32 {
            for x in center - 70..center + 70 {
                let dx = x - center;
                let head = (dx as f64 / 21.0).powi(2) + ((y - 91) as f64 / 26.0).powi(2) <= 1.0;
                let neck = dx.abs() <= 8 && (114..132).contains(&y);
                let torso_width = if side { 18 } else { 40 - (y - 130).max(0) / 9 };
                let torso = (130..274).contains(&y) && dx.abs() <= torso_width;
                let arm = (140..277).contains(&y)
                    && if side {
                        dx.abs() <= 7
                    } else {
                        (37..=48).contains(&dx.abs())
                    };
                let hands = (274..292).contains(&y)
                    && if side {
                        dx.abs() <= 9
                    } else {
                        (36..=49).contains(&dx.abs())
                    };
                let legs = (263..432).contains(&y)
                    && if side {
                        dx.abs() <= 13
                    } else {
                        (7..=29).contains(&dx.abs())
                    };
                let feet = (430..446).contains(&y)
                    && if side {
                        (-14..=32).contains(&dx)
                    } else {
                        (5..=36).contains(&dx.abs())
                    };
                if head || neck || torso || arm || hands || legs || feet {
                    canvas.put_pixel(x as u32, y as u32, image::Rgb([150, 150, 150]));
                }
            }
        }
    }
    let mut bytes = std::io::Cursor::new(Vec::new());
    image::DynamicImage::from(canvas)
        .write_to(&mut bytes, image::ImageFormat::Png)
        .map_err(|error| format!("创建角色构图参考失败：{error}"))?;
    Ok(format!(
        "data:image/png;base64,{}",
        base64::engine::general_purpose::STANDARD.encode(bytes.into_inner())
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_li_chen_panorama_and_small_thumbnails() {
        let canvas = ImageCanvas::for_quality("2K", "3:2").unwrap();
        assert!(
            canvas
                .validate_dimensions(2048, 512)
                .unwrap_err()
                .contains("比例不合格")
        );
        assert!(
            canvas
                .validate_dimensions(768, 512)
                .unwrap_err()
                .contains("分辨率不足")
        );
        assert!(canvas.validate_dimensions(2560, 1696).is_ok());
        assert!(canvas.validate_dimensions(3072, 2048).is_ok());
    }

    #[test]
    fn permits_provider_pixel_alignment_but_not_wrong_orientation() {
        let canvas = ImageCanvas::for_quality("2K", "16:9").unwrap();
        assert!(canvas.validate_dimensions(2592, 1472).is_ok());
        assert!(canvas.validate_dimensions(1440, 2560).is_err());
    }

    #[test]
    fn invalid_input_never_falls_back_to_adaptive_size() {
        for ratio in ["", "auto", "0:1", "-1:2", "NaN:1", "inf:1", "4:1", "1:4"] {
            assert!(ImageCanvas::for_quality("2K", ratio).is_err(), "{ratio}");
        }
        assert!(ImageCanvas::for_quality("auto", "3:2").is_err());
        assert!(ImageCanvas::parse("2K").is_err());
        assert!(ImageCanvas::parse("0x2048").is_err());
    }

    #[test]
    fn rejects_correct_ratio_but_cropped_character_sheet() {
        let mut canvas = image::RgbImage::from_pixel(300, 200, image::Rgb([225, 225, 225]));
        for x in 40..95 {
            for y in 20..200 {
                canvas.put_pixel(x, y, image::Rgb([35, 35, 35]));
            }
        }
        assert!(
            validate_role_margins(&canvas.clone().into())
                .unwrap_err()
                .contains("疑似被裁切")
        );
        for x in 0..300 {
            for y in 180..200 {
                canvas.put_pixel(x, y, image::Rgb([225, 225, 225]));
            }
        }
        assert!(validate_role_margins(&canvas.into()).is_ok());
    }

    #[test]
    fn detects_clipping_against_transparent_background() {
        let mut canvas = image::RgbaImage::new(300, 200);
        for x in 40..95 {
            for y in 0..180 {
                canvas.put_pixel(x, y, image::Rgba([20, 20, 20, 255]));
            }
        }
        assert!(validate_role_margins(&canvas.into()).is_err());
    }

    #[test]
    fn layout_references_have_full_figures_and_match_canvas_ratio() {
        use base64::Engine;
        for (four, width) in [(false, 768), (true, 1024)] {
            let data = role_layout_reference(four).unwrap();
            let bytes = base64::engine::general_purpose::STANDARD
                .decode(data.split_once(',').unwrap().1)
                .unwrap();
            let image = image::load_from_memory(&bytes).unwrap();
            assert_eq!((image.width(), image.height()), (width, 512));
            assert!(validate_role_margins(&image).is_ok());
        }
    }
}
