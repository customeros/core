import { useState } from 'react';
import { router } from '@inertiajs/react';

import { Button } from 'src/components/Button';
import { Dot } from 'src/components/Dot';
import { FeaturedIcon } from 'src/components/FeaturedIcon/FeaturedIcon';
import { Icon, IconName } from 'src/components/Icon';

export default function Welcome() {
  const [currentSlide, setCurrentSlide] = useState(1);

  const slides = [
    {
      title: '20 highly-qualified leads',
      description:
        'CustomerOS automatically created an Ideal Customer Profile of you and found 20 leads that match it.',
      icon: 'magnet',
    },
    {
      title: "See who's ready to buy",
      description:
        "Track lead intent in real time—know where they are in their journey and who's ready to buy with a simple web tracker setup.",
      icon: 'radar',
    },
    {
      title: 'Know what to do next',
      description:
        'With account briefs, find out why leads match your ICP, how they interacted with you and what the next steps are.',
      icon: 'briefcase-02',
    },
  ];

  const slideCount = slides.length;

  const getRelativeIndex = (index: number) => {
    const diff = index - currentSlide;
    if (diff > slideCount / 2) return diff - slideCount;
    if (diff < -slideCount / 2) return diff + slideCount;
    return diff;
  };

  const getTransformStyle = (relativeIndex: number) => {
    const baseX = 420;
    const translateX = relativeIndex * baseX;
    const scale = relativeIndex === 0 ? 1 : 0.9;
    const opacity = relativeIndex === 0 ? 1 : 0.5;
    const zIndex = 10 - Math.abs(relativeIndex);

    return {
      transform: `translateX(${translateX}px) scale(${scale})`,
      opacity,
      zIndex,
    };
  };

  return (
    <div className="w-screen flex flex-col items-center justify-start px-4 h-screen bg-white relative overflow-x-hidden animate-fadeIn">
      <div className="bg-[url('/images/half-circle-pattern.svg')] bg-cover bg-center bg-no-repeat w-[700px] h-[700px] absolute top-0 left-1/2 -translate-x-1/2 -translate-y-[40%]">
        <div className="flex flex-col items-center justify-between h-full pt-[35%] translate-y-[28%] pb-8">
          <div className="flex flex-col items-center">
            <div className="bg-[url('/images/box-illustration.svg')] w-[152px] h-[130px] bg-cover bg-center bg-no-repeat" />

            <h1 className="text-xl font-semibold text-gray-900 mt-8">Welcome!</h1>
            <p className="text-sm text-gray-500 mt-2">3 things you can do in CustomerOS…</p>

            <div className="relative mt-8 h-[260px] flex items-center justify-center w-full max-w-4xl">
              <div className="relative w-full h-full flex items-center justify-center">
                <div className="absolute left-[-480px] top-0 bottom-0 w-[280px] bg-gradient-to-r from-white to-transparent z-20 pointer-events-none" />
                <div className="absolute right-[-480px] top-0 bottom-0 w-[280px] bg-gradient-to-l from-white to-transparent z-20 pointer-events-none" />

                {slides.map((slide, index) => {
                  const rel = getRelativeIndex(index);
                  if (Math.abs(rel) > 1) return null;

                  return (
                    <div
                      key={index}
                      className="absolute transition-all duration-500 ease-in-out w-[380px] cursor-pointer"
                      style={getTransformStyle(rel)}
                      onClick={() => setCurrentSlide(index)}
                      onTouchStart={e => {
                        const touch = e.touches[0];
                        const startX = touch.clientX;

                        const handleTouchMove = (e: TouchEvent) => {
                          const touch = e.touches[0];
                          const currentX = touch.clientX;
                          const diff = startX - currentX;

                          if (Math.abs(diff) > 50) {
                            if (diff > 0) {
                              setCurrentSlide(prev => (prev + 1) % slides.length);
                            } else {
                              setCurrentSlide(prev => (prev - 1 + slides.length) % slides.length);
                            }
                            document.removeEventListener('touchmove', handleTouchMove);
                          }
                        };

                        document.addEventListener('touchmove', handleTouchMove);
                      }}
                    >
                      <div className="bg-white rounded-xl shadow-lg p-6 text-center border border-gray-200 flex flex-col items-center gap-4">
                        <FeaturedIcon colorScheme="primary" size="md">
                          <Icon name={slide.icon as IconName} />
                        </FeaturedIcon>
                        <h2 className="text-base font-semibold text-primary-600 mb-2">
                          {slide.title}
                        </h2>
                        <p className="text-sm text-gray-600">{slide.description}</p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="flex justify-center gap-2 mt-6">
              {slides.map((_, index) => (
                <Dot
                  key={index}
                  onClick={() => setCurrentSlide(index)}
                  className={`w-2.5 h-2.5 rounded-full transition-colors duration-300 cursor-pointer`}
                  colorScheme={currentSlide === index ? 'primary' : 'gray'}
                  aria-label={`Go to slide ${index + 1}`}
                />
              ))}
            </div>
          </div>

          <Button
            className="mt-4 font-medium"
            variant="ghost"
            onClick={() => {
              router.visit('/leads');
            }}
          >
            Skip & Open app
          </Button>
        </div>
      </div>
    </div>
  );
}
