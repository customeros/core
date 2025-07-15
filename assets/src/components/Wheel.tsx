import { useRef, useMemo, useState, useEffect } from 'react';
import { TrackDetails, useKeenSlider, KeenSliderOptions } from 'keen-slider/react';

import { cn } from 'src/utils/cn';
import { useOnLongPress } from 'rooks';

import { Icon } from './Icon';
import { IconButton } from './IconButton';

export default function Wheel(props: {
  width: number;
  label?: string;
  loop?: boolean;
  initIdx?: number;
  values?: string[];
  onValueChange?: (value: string | number) => void;
  setValue?: (relative: number, absolute: number) => string;
}) {
  const wheelSize = 20;
  const slides = props.values?.length || 1;
  const slideDegree = 360 / wheelSize;
  const slidesPerView = props.loop ? 9 : 1;
  const [isDragging, setIsDragging] = useState(false);
  const [sliderState, setSliderState] = useState<TrackDetails | null>(null);
  const size = useRef(0);

  const longPressRef = useOnLongPress(
    () => {
      setIsDragging(true);
    },
    {
      duration: 100,
      onClick: () => setIsDragging(false),
    }
  );

  const options = useMemo<KeenSliderOptions>(
    () => ({
      slides: {
        number: slides,
        origin: props.loop ? 'center' : 'auto',
        perView: slidesPerView,
      },
      renderMode: 'performance',
      vertical: false, // horizontal
      initial: props.initIdx || 0,
      loop: props.loop || false,
      dragSpeed: val => {
        const width = size.current;

        return (
          val * (width / ((width / 2) * Math.tan(slideDegree * (Math.PI / 180))) / slidesPerView)
        );
      },
      created: s => {
        size.current = s.size;
      },
      updated: s => {
        size.current = s.size;
      },
      detailsChanged: s => {
        setSliderState(s.track.details);
        props.onValueChange?.(s.track.details.abs);
      },
      rubberband: !props.loop,
      mode: 'free-snap',
    }),
    [props.initIdx, props.loop, props.values, slides, slidesPerView]
  );

  const [sliderRef, slider] = useKeenSlider<HTMLDivElement>(options);
  const [radius, setRadius] = useState(0);

  useEffect(() => {
    if (slider.current) setRadius(slider.current.size / 2);
  }, [slider]);

  function slideValues() {
    if (!sliderState) {
      return [];
    }
    const offset = props.loop ? 1 / 2 - 1 / slidesPerView / 2 : 0;
    const values = [];

    for (let i = 0; i < slides; i++) {
      const slide = sliderState.slides[i];
      const distance = sliderState ? (slide?.distance - offset) * slidesPerView : 0;
      const rotate = distance * (360 / wheelSize) * -1;

      const style = {
        transform: `rotateY(${rotate}deg) translateZ(${radius}px)`,
        WebkitTransform: `rotateY(${rotate}deg) translateZ(${radius}px)`,
      };

      // Calculate transition value based on distance from center
      const transitionValue = Math.max(0, Math.min(1, 1 - Math.abs(distance) * 1.5));

      // Set opacity: lower for slides behind (rotate > 90deg or < -90deg)
      const opacity = Math.abs(rotate) > 90 ? 0 : 1; // 0.2 for back, 1 for front

      values.push({
        style: { ...style, opacity },
        value: props.values?.[i] || i,
        transitionValue,
      });
    }

    return values;
  }

  return (
    <div className="flex items-center justify-center h-full">
      <div
        ref={sliderRef}
        className="relative flex flex-col items-center w-full h-full select-none bg-white transition-colors duration-200"
      >
        <div className="flex-1 flex items-center justify-center w-full">
          <div
            ref={longPressRef}
            className={cn(
              'relative w-full h-full flex items-center justify-center cursor-grab',
              isDragging && 'cursor-grabbing'
            )}
          >
            {slideValues().map(({ style, value, transitionValue }, idx) => (
              <div
                key={idx}
                style={style}
                className={cn(
                  'absolute flex items-center justify-center h-full text-md text-gray-700 transition-colors duration-200 z-10',
                  isDragging && 'cursor-grabbing'
                )}
              >
                <span
                  onClick={() => {
                    slider.current?.moveToIdx(idx);
                  }}
                  style={{
                    backgroundColor: `rgba(219, 234, 254, ${transitionValue})`,
                  }}
                  className={cn(
                    'block px-4 py-1 rounded cursor-pointer after:content-["after:absolute after:top-[4px] after:right-0 after:w-[1px] after:h-[calc(100%-4px)] after:bg-gradient-to-t after:from-gray-200 after:to-transparent hover:bg-gray-100',
                    isDragging && 'cursor-grabbing'
                  )}
                >
                  {value}
                </span>
              </div>
            ))}
          </div>
          <div className="absolute top-1/2 left-1/2 -translate-x-[calc(1px)] -translate-y-1/2 mt-0 text-sm font-medium text-gray-700">
            <div className="w-[2px] h-[52px] ring-1 ring-primary-500 bg-primary-500 rounded-sm"></div>
          </div>
        </div>
        <div className="w-full h-[1px] bg-gradient-to-r from-transparent via-gray-200 to-transparent" />
        <div className="absolute bottom-[-46px] flex gap-2">
          <IconButton
            variant="ghost"
            className="z-20"
            aria-label="Previous"
            icon={<Icon name="chevron-left" />}
            onClick={() => {
              slider.current?.next();
            }}
          />
          <div
            className={cn(
              'w-4 h-4 flex items-center mt-[10px] cursor-grab text-gray-500',
              isDragging && 'cursor-grabbing text-primary-500'
            )}
          >
            <Icon name="handle-drag" className={cn('w-4 h-4')} />
          </div>
          <IconButton
            variant="ghost"
            className="z-20"
            aria-label="Next"
            icon={<Icon name="chevron-right" />}
            onClick={() => {
              slider.current?.prev();
            }}
          />
        </div>
      </div>
    </div>
  );
}
