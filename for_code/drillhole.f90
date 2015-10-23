!-----------------------------------------------------------------------
!   PyGSLIB Desurvey, Module to calculate drillhole coordinates at 
!   interval tables and other drillhole relate process.  
! 
!   Copyright (C) 2015 Adrian Martinez Vargas 
!
!   This program is free software; you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation; either version 3 of the License, or
!   any later version.
!    
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!   GNU General Public License for more details.
!   
!   You should have received a copy of the GNU General Public License
!   along with this program.  If not, see <http://www.gnu.org/licenses/>
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! functions to interpolate angles at drillhole, ex, in assay from survey 
!----------------------------------------------------------------------- 

subroutine ang2cart(azm,dip,x,y,z)
    ! ------------------------------------------------------------------
    ! get azimuth and dip (downward positive) and convert it to x,y,z
    ! angles are in degrees
    ! x,y,z are vectors with origin 0,0,0
    ! for example: [0,x]
    ! ------------------------------------------------------------------
    
    implicit none
    
    ! inout 
    real, intent(in) :: azm,dip
    real, intent(out) :: x,y,z
    
    ! internal
    real :: razm,rdip, DEG2RAD
    
    DEG2RAD=3.141592654/180.0
    
    ! convert degree to rad and correct sign of dip
    razm = azm * DEG2RAD
    rdip = -dip * DEG2RAD

    ! do the conversion
    x = sin(razm) * cos(rdip)
    y = cos(razm) * cos(rdip)
    z = sin(rdip)
    
    return
    
end subroutine ang2cart

subroutine cart2ang(x,y,z,azm,dip)
    ! ------------------------------------------------------------------
    ! convert x,y,z to azimuth, dip (downward positive) 
    ! angles are in degrees
    ! x,y,z are assumed vectors with origin 0,0,0
    ! for example: [0,x]
    ! ------------------------------------------------------------------
    
    implicit none
    
    ! inout 
    real, intent(out) :: azm,dip
    real, intent(in) :: x,y,z
    
    ! internal
    real :: razm,rdip, RAD2DEG, pi
    
    RAD2DEG=180.0/3.141592654
    pi = 3.141592654

    if (x/=0. .and. y/= 0.) then 
        azm= atan2(x,y)
        if (azm<0) azm= azm + pi*2
        azm = azm * RAD2DEG
    else
        azm = 0
    end if 
    
    dip = -asin(z) * RAD2DEG
    
    return 

end subroutine cart2ang


subroutine interp_ang1D(azm1,dip1,azm2,dip2,len12,d1, azm,dip)
    ! ------------------------------------------------------------------
    ! Interpolate the azimuth and dip angle over a line:
    !   given two points (p1, p2) over a line (1D problem);
    !   this subroutine calculate the average azimuth and dip of a point 
    !   between p1 and p2, located at a distance d1 from p1 one and a 
    !   distance len12-d1 from p2
    !   
    !   to do this we convert the (azimuth,dip) to (x,y,z), we 
    !   interpolate x,y,z and then we convert back to (azimuth,dip)
    ! 
    ! ------------------------------------------------------------------
    
    implicit none
    
    ! inout 
    real, intent(out) :: azm,dip
    real, intent(in) :: azm1,dip1,azm2,dip2,len12,d1
    
    ! internal
    real :: x1,y1,z1,x2,y2,z2,x,y,z
    
    
    ! convert angles to coordinates
    call ang2cart(azm1,dip1,x1,y1,z1)
    call ang2cart(azm2,dip2,x2,y2,z2)
    
    ! interpolate x,y,z
    x = x2*d1/len12 + x1*(len12-d1)/len12 
    y = y2*d1/len12 + y1*(len12-d1)/len12
    z = z2*d1/len12 + z1*(len12-d1)/len12
    
    ! get back the results as angles
    call cart2ang(x,y,z,azm,dip)
    
    return
    
end subroutine interp_ang1D


!-----------------------------------------------------------------------
! functions to put in assay x,y,z from collar
!----------------------------------------------------------------------- 
subroutine collr2tbl(nc,idc,xc,yc,zc,nt,idt,xt,yt,zt)
    
    ! this works only with sorted arrays
    
    implicit none
    
    !input
    integer, intent(in) :: nc,nt
    integer, intent(in), dimension(nc) :: idc
    real, intent(in), dimension(nc) :: xc,yc,zc
    integer, intent(in), dimension(nt) :: idt
    
    !output
    real, intent(out), dimension(nt) :: xt,yt,zt
    
    !internal
    integer :: i,j,actualc
    
    actualc=0
    do i=0,nt
        ! find the first collar similar to i starting from last found
        do j=actualc,nc   ! actual will skip already found
            if (idt(i)==idc(j)) then
                xt(i)=xc(j)
                yt(i)=yc(j)
                zt(i)=zc(j)
                actualc = j 
                exit
            end if
        end do  
    end do
    
end subroutine collr2tbl

!-----------------------------------------------------------------------
! functions to put in assay az, dip from survey
!----------------------------------------------------------------------- 
subroutine surv2tbl(ns,ids,lengs,azs,dips,nt,idt,fromt,midt,tot, &
                    azbs,dipbs,azms,dipms,azes,dipes)
    
    ! this works only with sorted arrays
    
    implicit none
    
    !input
    integer, intent(in) :: ns,nt
    integer, intent(in), dimension(ns) :: ids
    real, intent(in), dimension(ns) :: azs,dips,lengs
    integer, intent(in), dimension(nt) :: idt
    real, intent(in), dimension(nt) :: fromt,midt,tot
    
    !output (anges at begin, mid and end interval)
    real, intent(out), dimension(nt) :: azbs,dipbs,azms,dipms,azes,dipes
    
    !internal
    integer :: i,j,actualt
    real :: a, b, azm1,dip1,azm2,dip2,len12,d1
    
    actualt=0
    do i=1,ns-1
        ! get the segment [a-b] to test intervals in the table
        if (ids(i)==ids(i+1)) then
            a=lengs(i)
            b=lengs(i+1)
            azm1 = azs(i)
            dip1 = dips(i)
            azm2 = azs(i+1)
            dip2 = dips(i+1)
            len12 = lengs(i+1)-lengs(i)
        else
            cycle
        end if
        
        ! now loop in the table to test the interval
        do j=actualt,nt  
            ! if we are in the right drillhole
            if (ids(i)==idt(j)) then
                ! test if we are in the interval, interpolate angles
                if (fromt(j)>=a .AND. fromt(j)<=b ) then                     
                    d1= fromt(j)- a
                    call interp_ang1D(azm1,dip1,azm2,dip2,len12,d1,azbs(j),dipbs(j))
                end if 
                if (midt(j)>=a  .AND. midt(j)<=b ) then
                    d1= midt(j)- a
                    call interp_ang1D(azm1,dip1,azm2,dip2,len12,d1,azms(j),dipms(j))
                end if
                if (tot(j)>=a   .AND. tot(j)<=b ) then
                    d1= tot(j)- a
                    call interp_ang1D(azm1,dip1,azm2,dip2,len12,d1,azes(j),dipes(j))
                end if
                actualt = j 
                cycle
            end if
        end do  
    end do
    
end subroutine surv2tbl


!-----------------------------------------------------------------------
! functions to desurvey assay tables (assuming you have x,y,z,az,dip)
!----------------------------------------------------------------------- 

subroutine dsmincurb(len12,az1,dip1,az2,dip2,dz,dn,de)
    ! using formulas in http://www.cgg.com/data//1/rec_docs/2269_MinimumCurvatureWellPaths.pdf
    
    ! here we calculate the deltas only... 
    
    implicit none
    
    ! input
    real, intent(in) :: len12,az1,dip1,az2,dip2  ! az2,dip2  not used but keep it for other methods
    
    ! output
    real, intent(out) :: dz,dn,de 


    ! internal 
    real :: i1, a1, i2, a2 , DEG2RAD, rf, dl
    
    DEG2RAD=3.141592654/180.0
    
    i1 = (90 - dip1) * DEG2RAD
    a1 = az1 * DEG2RAD
    
    i2 = (90 - dip2) * DEG2RAD
    a2 = az2 * DEG2RAD
    
    ! calculate the dog-leg (dl) and the Ratio Factor (rf)
    dl = acos(cos(i2-i1)-sin(i1)*sin(i2)*(1-cos(a2-a1)))
    rf = 2*tan(dl/2)/dl 
    
    
    dz = 0.5*len12*(cos(i1)+cos(i2))*rf
    dn = 0.5*len12*(sin(i1)*cos(a1)+sin(i2)*cos(a2))*rf
    de = 0.5*len12*(sin(i1)*sin(a1)+sin(i2)*sin(a2))
    
    return
    
end subroutine dsmincurb


subroutine dstang(len12,az1,dip1,az2,dip2,dz,dn,de)
    ! using formulas in http://www.cgg.com/data//1/rec_docs/2269_MinimumCurvatureWellPaths.pdf
    
    ! here we calculate the deltas only... 
    
    implicit none
    
    ! input
    real, intent(in) :: len12,az1,dip1,az2,dip2  ! az2,dip2  not used but keep it for other methods
    
    ! output
    real, intent(out) :: dz,dn,de 


    ! internal 
    real :: i1, a1, DEG2RAD
    
    DEG2RAD=3.141592654/180.0
    
    i1 = (90 - dip1) * DEG2RAD
    a1 = az1 * DEG2RAD
    
    dz = len12*cos(i1)
    dn = len12*sin(i1)*cos(a1)
    de = len12*sin(i1)*sin(a1)
    
    return
    
end subroutine dstang