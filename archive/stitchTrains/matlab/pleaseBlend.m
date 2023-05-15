function blended_image  = pleaseBlend(image_one, image_two, blend_length)
    %TODO: check for the size of the images to be same before continuing
    if ~((blend_length == 0) || (blend_length == 1)) 

        sz_im  = size(image_one);
        append_zero    = zeros(sz_im(1), blend_length, sz_im(3));
        cast(append_zero,'like',image_one);
        blended_part   = append_zero; %cause we need the matrix of the same size as 
        image_one_part = image_one(:,end-blend_length:end,:);
        image_two_part = image_two(:,1:blend_length,:);
        for i=1:blend_length
            alpha               =  (blend_length - (i-1))/(blend_length);
            blended_part(:,i,:) =  alpha*(image_one_part(:,i,:)) + (1-alpha)*image_two_part(:,i,:);
        end
        blended_image = [image_one(:,1:end-blend_length,:) blended_part image_two(:,blend_length:end,:)];
    else
        blended_image = [image_one image_two];
    end
    
%     imshow(blended_image);
%     figure
%     imshow(blended_part);
%     
    