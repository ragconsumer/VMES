centersqueeze1 = [repeat([2.1,1,0], outer=(1,5));;
                repeat([0,2,0.5], outer=(1,2));;
                repeat([0,1,2], outer=(1,4))]

centersqueeze2 = [repeat([2.1,0,1], outer=(1,6));; #tie for first and second
                repeat([0,2,0.5], outer=(1,3));;
                repeat([0,0.8,1.2], outer=(1,3))]

fivecand2party = [repeat([5.1,4.2,0,-3.5,-6], outer=(1,8));;
                    repeat([5.1,6.2,1.3,-3.5,-4], outer=(1,4));;
                    repeat([0,0.1,3,.6,.5], outer=(1,6));;
                    repeat([-2.6,-0.5,0.4,3,4], outer=(1,5));;
                    repeat([-2.6,-0.5,0.4,4,3], outer=(1,6))]
fivecand2partymessier = [repeat([5.1,4.2,0,-3.5,-6], outer=(1,6));;
                        repeat([5.1,2.2,0,3.5,-6], outer=(1,2));;
                        repeat([5.1,6.2,1.3,-3.5,-4], outer=(1,4));;
                        repeat([0,0.1,3,.6,.5], outer=(1,6));;
                        repeat([-2.6,-0.5,0.4,3,4], outer=(1,5));;
                        repeat([-2.6,-0.5,0.4,4,3], outer=(1,6))]
reversespoiler = [repeat([10,9,0], outer=(1,12));;
                repeat([9,10,7], outer=(1,6));;
                repeat([0,1,5], outer=(1,2))]

manybulletranked = [repeat([4,3,0,0,0], outer=(1,5));;
                    repeat([0,0,4,0,0], outer=(1,6));;
                    repeat([0,4,2,3,0], outer=(1,4));;
                    repeat([0,0,0,0,4], outer=(1,3));;
                    repeat([0,2,1,4,3], outer=(1,20));;
                    repeat([4,0,0,3,0], outer=(1,2));;]