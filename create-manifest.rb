require 'json'
require 'time'
require 'fileutils'

class MahjongImage
  attr_accessor :source_ref, :image_size, :annotations

  def initialize(source_ref, image_size, annotations)
    @source_ref = source_ref
    @image_size = image_size
    @annotations = annotations

    @label_attribute = "test8" # Ground Truth job name? - it seems that it does not have to match the project name
  end

  def to_h
    {
      "source-ref" => @source_ref,
      "#@label_attribute" => {
        "image_size" => [@image_size],
        "annotations" => @annotations.map(&:to_h)
      },
      "#{@label_attribute}-metadata" => {
        "objects" => @annotations.map { { "confidence" => 0 } },
        "class-map" => {
          "0" => "1m", "1" => "2m", "2" => "3m", "3" => "4m", "4" => "5m", "5" => "6m", "6" => "7m", "7" => "8m", "8" => "9m",
          "9" => "1p", "10" => "2p", "11" => "3p", "12" => "4p", "13" => "5p", "14" => "6p", "15" => "7p", "16" => "8p", "17" => "9p",
          "18" => "1s", "19" => "2s", "20" => "3s", "21" => "4s", "22" => "5s", "23" => "6s", "24" => "7s", "25" => "8s", "26" => "9s",
          "27" => "ton", "28" => "nan", "29" => "sha", "30" => "pei", "31" => "haku", "32" => "hatsu", "33" => "chun"
        },
        "type" => "groundtruth/object-detection",
        "human-annotated" => "yes",
        "creation-date" => Time.now.strftime('%Y-%m-%dT%H:%M:%S.%6N'),
        "job-name" => "labeling-job/#{@label_attribute}"
      }
    }
  end
end

class Annotation
  attr_accessor :class_id, :top, :left, :height, :width

  def initialize(class_id, top, left, height, width)
    @class_id = class_id
    @top = top
    @left = left
    @height = height
    @width = width
  end

  def to_h
    {
      "class_id" => @class_id,
      "top" => @top,
      "left" => @left,
      "height" => @height,
      "width" => @width
    }
  end
end

def process_line(line)
  data = JSON.parse(line)
  annotations = data["annotations"].map do |anno|
    Annotation.new(anno["class_id"], anno["top"], anno["left"], anno["height"], anno["width"])
  end

  MahjongImage.new(data["source_ref"], data["image_size"], annotations)
end

def convert_to_json(input_file_path)
  # アウトプットファイルのパスを決定
  output_file_path = input_file_path.sub(/\.data$/, '.json')
  puts "S3 path is #{output_file_path}"

  # 入力ファイルを1行ずつ処理
  File.readlines(input_file_path).each do |line|
    mahjong_image = process_line(line)
    manifest_json = mahjong_image.to_h.to_json

    # マニフェストファイルに追記
    File.open(output_file_path, "a") do |file|
      file.puts manifest_json
    end
  end
end

# スクリプトの引数からインプットファイルのパスを取得
input_file_path = ARGV[0]

# 引数が提供されているかどうかを確認
if input_file_path.nil?
  puts "Please provide an input file path."
  exit
end

# JSONへの変換処理を実行
convert_to_json(input_file_path)
