subroutine print_initial_mesh
    use Types
    use ParamIO
    use Mesh
    use Printparameters, only: initial_mesh_print_unit
    implicit none

    ! Local Variables
    integer      :: i, jp, k, lmn, n,iz,izstart,status, nnodes
    integer      :: n_printable_nodes,n_printable_elements,ntotalvars
    integer      :: iof
    character ( len = 130 ) :: tecplotstring
    
    real(prec) :: xx(3)

    character (len=20) :: format_string
    character (len=4)  :: char4

    integer, allocatable :: node_numbers(:)                  ! Nodes need to be re-numbered for TECPLOT if not all nodes are printed
    logical, allocatable :: zone_print_flag(:)
    integer, allocatable :: zone_dimension(:)
  
    
    ! Print initial mesh to a file that may be read by TECPLOT

    allocate(node_numbers(n_nodes), stat = status)
    allocate(zone_print_flag(n_zones), stat=status)
    allocate(zone_dimension(n_zones), stat=status)
  
    zone_print_flag(1:n_zones) = .true.
    zone_dimension(1:n_zones) = 0
  
    if (status /=0) then
        write(IOW,*) ' Error in subroutine print_initial_mesh '
        write(IOW,*) ' Unable to allocate storage for printing solution '
        stop
    endif

    do iz = 1,n_zones
        if (.not.zone_print_flag(iz)) cycle
        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
            do k = 1,element_list(lmn)%n_nodes
                n = connectivity(element_list(lmn)%connect_index+k-1)
                if (node_list(n)%n_coords==2) then
                    if (zone_dimension(iz)==0) then
                        zone_dimension(iz) = 2
                    else if (zone_dimension(iz) /=2) then
                        write(IOW,*) ' *** Warning *** '
                        write(IOW,*) ' A zone to be printed using a PRINT INITIAL MESH command contains nodes with'
                        write(IOW,*) ' an inconsistent number of coordinates '
                        write(IOW,*) ' This zone will not be printed '
                        zone_print_flag(iz) = .false.
                        exit
                    endif

                else if (node_list(n)%n_coords==3) then
                    if (zone_dimension(iz)==0) then
                        zone_dimension(iz) = 3
                    else if (zone_dimension(iz) /=3) then
                        write(IOW,*) ' *** Warning *** '
                        write(IOW,*) ' A zone to be printed using a PRINT INITIAL MESH command contains nodes with'
                        write(IOW,*) ' an inconsistent number of coordinates '
                        write(IOW,*) ' This zone will not be printed '
                        zone_print_flag(iz) = .false.
                        exit
                    endif
                endif
            end do
            if (.not.zone_print_flag(iz)) exit
            if (zone_dimension(iz)==2) then
                if (element_list(lmn)%n_nodes == 3) cycle
                if (element_list(lmn)%n_nodes == 4) cycle
                if (element_list(lmn)%n_nodes == 6) cycle
                if (element_list(lmn)%n_nodes == 8) cycle
                if (element_list(lmn)%n_nodes == 9) cycle
            else if (zone_dimension(iz)==3) then
                if (element_list(lmn)%n_nodes == 4) cycle
                if (element_list(lmn)%n_nodes == 8) cycle
            endif
            write(IOW,*) ' *** Warning *** '
            write(IOW,*) ' A zone to be printed using a PRINT INITIAL MESH command contains elements with'
            write(IOW,*) ' a number of nodes that cannot be printed'
            write(IOW,*) ' This zone will not be printed '
            zone_print_flag(iz) = .false.
        end do
    end do

    ! Find the first zone to print
    do izstart = 1,n_zones
        if (zone_print_flag(izstart)) exit
    end do
                        
    if (zone_dimension(izstart)==2) then
        tecplotstring = 'VARIABLES = X,Y'
    else if (zone_dimension(izstart)==3) then
        tecplotstring = 'VARIABLES = X,Y,Z'
    endif
    !
    ! print is done zone by zone
    !
    do iz = izstart,n_zones                             ! Loop over zones

        !   Write a header for separate zones
        node_numbers(1:n_nodes) = 0
        n_printable_elements = 0
        n_printable_nodes = 0
        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
            if (zone_dimension(iz)==2) then
                if (element_list(lmn)%n_nodes == 3) n_printable_elements = n_printable_elements + 1
                if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
                if (element_list(lmn)%n_nodes == 6) n_printable_elements = n_printable_elements + 4
                if (element_list(lmn)%n_nodes == 8) n_printable_elements = n_printable_elements + 1 ! corner nodes only
                if (element_list(lmn)%n_nodes == 9) n_printable_elements = n_printable_elements + 4
            else if (zone_dimension(iz)==3) then
                if (element_list(lmn)%n_nodes == 8) n_printable_elements = n_printable_elements + 1
                if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
            endif
            nnodes = element_list(lmn)%n_nodes
            if (zone_dimension(iz)==2) then
               if (element_list(lmn)%n_nodes == 8) nnodes = 4
            endif
            do k = 1,nnodes
                n = connectivity(element_list(lmn)%connect_index + k-1)
                if (node_numbers(n)==0) then
                    n_printable_nodes = n_printable_nodes + 1
                    node_numbers(n) = n_printable_nodes
                endif
            end do
        end do



        write(initial_mesh_print_unit,*) trim(tecplotstring)
        if (zone_dimension(iz)==2) then
            write (initial_mesh_print_unit,'(A10,A,A15,I5,A3,I5,A9)') ' ZONE, T="',trim(zone_namelist(iz)), &
                '" F=FEPOINT, I=', n_printable_nodes, ' J=', n_printable_elements
        else if (zone_dimension(iz)==3) then
            write (initial_mesh_print_unit,'(A10,A,A15,I5,A3,I5,A9)') ' ZONE, T="',trim(zone_namelist(iz)), &
                '" F=FEPOINT, I=', n_printable_nodes, ' J=', n_printable_elements,' ET=BRICK'
        endif
        ! Print the nodes
        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element

            nnodes = element_list(lmn)%n_nodes
            if (zone_dimension(iz)==2) then
               if (element_list(lmn)%n_nodes == 8) nnodes = 4
            endif
            do k = 1,nnodes
                n = connectivity(element_list(lmn)%connect_index + k-1)
                if (node_numbers(n)>0) then
                    node_numbers(n) = - node_numbers(n)          ! Prevents more prints
                    do i = 1, node_list(n)%n_coords
                        xx(i) = coords(node_list(n)%coord_index + i - 1)
                    end do
                    ntotalvars = node_list(n)%n_coords
                    if (ntotalvars<10) then
                        write(char4,'(I1)') ntotalvars
                    else
                        write(char4,'(I2)') ntotalvars
                    endif
                    format_string = '('// char4 //'(1X,E18.10))'
                    if (ntotalvars>0) then
                        iof = node_list(n)%dof_index
                        write (initial_mesh_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords)
                    endif
                endif
            end do
        end do
    
        node_numbers = -node_numbers             ! Remove the - flag that suppresses duplicate prints from node numbers

        ! Print the elements

        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
            jp = element_list(lmn)%connect_index
            if (zone_dimension(iz)==2) then
                if ( element_list(lmn)%n_nodes==9 ) then
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 3))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 4))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 4)),  &
                        node_numbers(connectivity(jp + 7)), &
                        node_numbers(connectivity(jp + 6))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 5)),  &
                        node_numbers(connectivity(jp + 8)), node_numbers(connectivity(jp + 7))
                else if ( element_list(lmn)%n_nodes==8 ) then ! Only corner nodes are printed for 2D serendipity element
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 3))
                else if ( element_list(lmn)%n_nodes==6 ) then
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 1)),  &
                        node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 4))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 2)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 4)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                else if ( element_list(lmn)%n_nodes==4 ) then
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 3))
                else if ( element_list(lmn)%n_nodes==3 ) then
                    write (initial_mesh_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 2))
                endif
            else if (zone_dimension(iz)==3) then
                if (element_list(lmn)%n_nodes==8) then
                    write(initial_mesh_print_unit,'(8(1x,i5))') (node_numbers(connectivity(jp+k)), k=0,7)
                end if
                if (element_list(lmn)%n_nodes ==4) then
                    write(initial_mesh_print_unit,'(4(1x,i5))') (node_numbers(connectivity(jp+k)), k=0,3)
                endif
            endif
        end do
    end do


    deallocate(node_numbers)
    deallocate(zone_print_flag)
    deallocate(zone_dimension)


end subroutine print_initial_mesh




!================================SUBROUTINE print_state ============================
subroutine print_state
    use Types
    use ParamIO
    use Globals, only : TIME, DTIME
    use Mesh
    use Printparameters
    implicit none

    ! Local Variables
    integer      :: i, jp, k, lmn, n,iz,izstart,status,n_auxiliary_nodes,auxiliary_node
    integer      :: n_printable_nodes,n_printable_elements,ntotalvars
    integer      :: iof
    character ( len = 130 ) :: tecplotstring
    character ( len = 4 ) :: dofstring
    real(prec) :: xx(3)

    character (len=20) :: format_string
    character (len=4)  :: char4

    integer, allocatable :: node_numbers(:)                  ! Nodes need to be re-numbered for TECPLOT if not all nodes are printed
    real (prec), allocatable :: lumped_projection_matrix(:)  ! Lumped mass matrix for projecting field variables from int pts to nodes
    real (prec), allocatable :: field_variables(:,:)         ! User-defined field variables to be printed
    real (prec), allocatable :: auxiliary_field_variables(:) ! Field variables at auxiliary nodes of quadratic elements
    real (prec), allocatable :: auxiliary_dof(:)             ! DOF at auxiliary nodes of quadratic elements
    real (prec), allocatable :: auxiliary_dof_increment(:)   ! DOF increment at auxiliary nodes of quadratic elements


        ! Print solution to a file that may be read by TECPLOT

    if (n_field_variables>0) then
        allocate(lumped_projection_matrix(n_nodes), stat = status)
        allocate(field_variables(n_field_variables,n_nodes), stat = status)
        allocate(auxiliary_field_variables(n_field_variables), stat=status)
    endif
    allocate(auxiliary_dof(maxval(zone_ndof)), stat=status)
    allocate(auxiliary_dof_increment(maxval(zone_ndof)), stat=status)
    allocate(node_numbers(n_nodes), stat = status)
    if (status /=0) then
        write(IOW,*) ' Error in subroutine print_state '
        write(IOW,*) ' Unable to allocate storage for printing solution '
        stop
    endif

    ! Find the first zone to print
    do izstart = 1,n_zones
        if (zone_print_flag(izstart)) exit
    end do
                        
    if (zone_dimension(izstart)==2) then
        tecplotstring = 'VARIABLES = X,Y'
    else if (zone_dimension(izstart)==3) then
        tecplotstring = 'VARIABLES = X,Y,Z'
    endif
    if (print_dof) then
        do i=1,zone_ndof(izstart)
            if (i < 10) then
                format_string = "(A2,I1)"
            else
                format_string = "(A2,I2)"
            endif
            write (dofstring,format_string) "DU",i
            tecplotstring = trim(tecplotstring)//','//trim(dofstring)
        enddo
        do i=1,zone_ndof(izstart)
            if (i < 10) then
                format_string = "(A1,I1)"
            else
                format_string = "(A1,I2)"
            endif
            write (dofstring,format_string) "U",i
            tecplotstring = trim(tecplotstring)//','//trim(dofstring)
        enddo
    endif
  
    if (n_field_variables>0) then
        do i = 1,n_field_variables
            tecplotstring = trim(tecplotstring)//','//trim(field_variable_names(i))
        end do
    end if
  
  
    ! If all zones are printed together, count all the printable elements and assign numbers to all printable nodes
    node_numbers = 0
    n_printable_nodes = 0
    n_auxiliary_nodes = 0
    n_printable_elements = 0
    if (combinezones) then
        do iz = izstart,n_zones
            if (.not.zone_print_flag(iz)) cycle
       
            do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
                if (zone_dimension(iz)==2) then
                    if (element_list(lmn)%n_nodes == 3) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 6) n_printable_elements = n_printable_elements + 4
                    if (element_list(lmn)%n_nodes == 8) then
                        n_printable_elements = n_printable_elements + 4
                        n_auxiliary_nodes = n_auxiliary_nodes + 1
                    endif
                    if (element_list(lmn)%n_nodes == 9) n_printable_elements = n_printable_elements + 4
                else if (zone_dimension(iz)==3) then
                    if (element_list(lmn)%n_nodes == 8) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
                endif
                do k = 1,element_list(lmn)%n_nodes
                    n = connectivity(element_list(lmn)%connect_index + k-1)
                    if (node_numbers(n)==0) then
                        n_printable_nodes = n_printable_nodes + 1
                        node_numbers(n) = n_printable_nodes
                    endif
                end do
            end do
        end do
    
        write(state_print_unit,*) trim(tecplotstring)
        if (zone_dimension(iz)==2) then
            write (state_print_unit,'(A10,D10.4,A15,I5,A3,I5,A9)') ' ZONE, T="',TIME+DTIME,&
                '" F=FEPOINT, I=', n_printable_nodes+n_auxiliary_nodes, ' J=', n_printable_elements
        else if (zone_dimension(iz)==3) then
            write (state_print_unit,'(A10,D10.4,A15,I5,A3,I5,A9)') ' ZONE, T="',TIME+DTIME, &
                '" F=FEPOINT, I=', n_printable_nodes+n_auxiliary_nodes, ' J=', n_printable_elements,' ET=BRICK'
        endif
    endif



    ! State print is done zone by zone, to allow discontinuities across zone
    ! boundaries
    !

    do iz = izstart,n_zones                             ! Loop over zones

        if (n_field_variables>0) then                     ! Project field variables for current zone
            lumped_projection_matrix = 0.d0
            field_variables = 0.d0
            call assemble_projection_mass_matrix(zone_list(iz)%start_element,zone_list(iz)%end_element,lumped_projection_matrix)
            call assemble_field_projection(zone_list(iz)%start_element,zone_list(iz)%end_element, &
                n_field_variables,field_variable_names,field_variables)
            do n = 1,n_nodes
                if (lumped_projection_matrix(n)>0.d0) then
                    field_variables(1:n_field_variables,n) = field_variables(1:n_field_variables,n)/lumped_projection_matrix(n)
                endif
            end do
        endif

        !   Write a header for separate zones
        if (.not.combinezones) then
            node_numbers = 0
            n_printable_elements = 0
            n_printable_nodes = 0
            n_auxiliary_nodes = 0
            do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
                if (zone_dimension(iz)==2) then
                    if (element_list(lmn)%n_nodes == 3) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 6) n_printable_elements = n_printable_elements + 4
                    if (element_list(lmn)%n_nodes == 8) then
                       n_printable_elements = n_printable_elements + 4
                       n_auxiliary_nodes = n_auxiliary_nodes+1
                    endif
                    if (element_list(lmn)%n_nodes == 9) n_printable_elements = n_printable_elements + 4
                else if (zone_dimension(iz)==3) then
                    if (element_list(lmn)%n_nodes == 8) n_printable_elements = n_printable_elements + 1
                    if (element_list(lmn)%n_nodes == 4) n_printable_elements = n_printable_elements + 1
                endif
                do k = 1,element_list(lmn)%n_nodes
                    n = connectivity(element_list(lmn)%connect_index + k-1)
                    if (node_numbers(n)==0) then
                        n_printable_nodes = n_printable_nodes + 1
                        node_numbers(n) = n_printable_nodes
                    endif
                end do
            end do
    
            write(state_print_unit,*) trim(tecplotstring)
            if (zone_dimension(iz)==2) then
                write (state_print_unit,'(A10,D10.4,A15,I5,A3,I5,A9)') ' ZONE, T="',TIME+DTIME,&
                    '" F=FEPOINT, I=', n_printable_nodes+n_auxiliary_nodes, ' J=', n_printable_elements
            else if (zone_dimension(iz)==3) then
                write (state_print_unit,'(A10,D10.4,A15,I5,A3,I5,A9)') ' ZONE, T="',TIME+DTIME,&
                    '" F=FEPOINT, I=', n_printable_nodes+n_auxiliary_nodes, ' J=', n_printable_elements,' ET=BRICK'
            endif
        endif


        ! Print the nodes
        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
            do k = 1,element_list(lmn)%n_nodes
                n = connectivity(element_list(lmn)%connect_index + k-1)
                if (node_numbers(n)>0) then
                    node_numbers(n) = - node_numbers(n)          ! Prevents more prints
                    do i = 1, node_list(n)%n_coords
                        xx(i) = coords(node_list(n)%coord_index + i - 1)
                    end do
                    if (print_displacedmesh) then
                        if (node_list(n)%n_displacements>0) then  ! Use the displacement map if one was provided
                            do i = 1,node_list(n)%n_coords
                                iof = node_list(n)%dof_index + displacement_map(node_list(n)%displacement_map_index + i-1)-1
                                xx(i) = xx(i) + displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                            end do
                        else   ! Otherwise if # DOF exceeds # coords assume first DOF are displacements
                            if (node_list(n)%n_coords<=node_list(n)%n_dof) then
                                do i = 1,node_list(n)%n_coords
                                    iof = node_list(n)%dof_index +  i-1
                                    xx(i) = xx(i) + displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                                end do
                            endif  ! Otherwise do not displace mesh
                        endif
                    endif

                    ntotalvars = node_list(n)%n_coords + n_field_variables
                    if (print_dof) ntotalvars = ntotalvars + 2*node_list(n)%n_dof
                    if (ntotalvars<10) then
                        write(char4,'(I1)') ntotalvars
                    else
                        write(char4,'(I2)') ntotalvars
                    endif
                    format_string = '('// char4 //'(1X,E18.10))'

                    if (print_dof.and.ntotalvars>0) then
                        iof = node_list(n)%dof_index
                        write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (dof_increment(iof+i), i=0,node_list(n)%n_dof-1), &
                            (dof_total(iof+i), i=0,node_list(n)%n_dof-1), &
                            (field_variables(i,n), i=1,n_field_variables)
                    else if (print_dof) then
                        iof = node_list(n)%dof_index
                        write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (dof_increment(iof+i), i=0,node_list(n)%n_dof-1), &
                            (dof_total(iof+i), i=0,node_list(n)%n_dof-1)
                    else if (ntotalvars>0) then
                        iof = node_list(n)%dof_index
                        write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (field_variables(i,n), i=1,n_field_variables)
                    endif

                endif
            end do
        end do

        ! Print auxiliary nodes for quadratic elements
        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
           if (element_list(lmn)%n_nodes == 8) then
              ! Coordinates, DOF, and field variables at the auxiliary node are found by interpolating to the center
              xx = 0.d0
              auxiliary_dof = 0.d0
              auxiliary_dof_increment = 0.d0
              if (n_field_variables>0) auxiliary_field_variables = 0.d0
              do k = 1,4
                 n = connectivity(element_list(lmn)%connect_index + k-1)
                 iof = node_list(n)%dof_index
                 do i = 1, node_list(n)%n_dof
                    auxiliary_dof(i) = auxiliary_dof(i) - 0.25d0*dof_total(iof+i-1)
                    auxiliary_dof_increment(i) = auxiliary_dof_increment(i) - 0.25d0*dof_increment(iof+i-1)
                 end do
                 if (n_field_variables>0) auxiliary_field_variables(1:n_field_variables) = &
                                            auxiliary_field_variables(1:n_field_variables) &
                                                - 0.25d0*field_variables(1:n_field_variables,n)
                 do i = 1, node_list(n)%n_coords
                    xx(i) = xx(i) - 0.25d0*coords(node_list(n)%coord_index + i - 1)
                 end do
                 if (print_displacedmesh) then
                     if (node_list(n)%n_displacements>0) then  ! Use the displacement map if one was provided
                         do i = 1,node_list(n)%n_coords
                             iof = node_list(n)%dof_index + displacement_map(node_list(n)%displacement_map_index + i-1)-1
                             xx(i) = xx(i) - 0.25d0*displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                         end do
                     else   ! Otherwise if # DOF exceeds # coords assume first DOF are displacements
                         if (node_list(n)%n_coords<=node_list(n)%n_dof) then
                             do i = 1,node_list(n)%n_coords
                                 iof = node_list(n)%dof_index +  i-1
                                 xx(i) = xx(i) - 0.25d0*displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                             end do
                         endif  ! Otherwise do not displace mesh
                     endif
                 endif
              end do
              do k = 5,8
                 n = connectivity(element_list(lmn)%connect_index + k-1)
                 iof = node_list(n)%dof_index
                 do i = 1, node_list(n)%n_dof
                    auxiliary_dof(i) = auxiliary_dof(i) + 0.5d0*dof_total(iof+i-1)
                    auxiliary_dof_increment(i) = auxiliary_dof_increment(i) + 0.5d0*dof_increment(iof+i-1)
                 end do
                 if (n_field_variables>0) auxiliary_field_variables(1:n_field_variables) = &
                                            auxiliary_field_variables(1:n_field_variables) &
                                                + 0.5d0*field_variables(1:n_field_variables,n)
                 do i = 1, node_list(n)%n_coords
                    xx(i) = xx(i) + 0.5d0*coords(node_list(n)%coord_index + i - 1)
                 end do
                 if (print_displacedmesh) then
                     if (node_list(n)%n_displacements>0) then  ! Use the displacement map if one was provided
                         do i = 1,node_list(n)%n_coords
                             iof = node_list(n)%dof_index + displacement_map(node_list(n)%displacement_map_index + i-1)-1
                             xx(i) = xx(i) + 0.5d0*displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                         end do
                     else   ! Otherwise if # DOF exceeds # coords assume first DOF are displacements
                         if (node_list(n)%n_coords<=node_list(n)%n_dof) then
                             do i = 1,node_list(n)%n_coords
                                 iof = node_list(n)%dof_index +  i-1
                                 xx(i) = xx(i) + 0.5d0*displacementscalefactor*(dof_total(iof) + dof_increment(iof))
                             end do
                         endif  ! Otherwise do not displace mesh
                     endif
                 endif
              end do


              ntotalvars = node_list(n)%n_coords + n_field_variables
              if (print_dof) ntotalvars = ntotalvars + 2*node_list(n)%n_dof
              if (ntotalvars<10) then
                  write(char4,'(I1)') ntotalvars
              else
                  write(char4,'(I2)') ntotalvars
              endif
              format_string = '('// char4 //'(1X,E18.10))'

              if (print_dof.and.ntotalvars>0) then
                 iof = node_list(n)%dof_index
                 write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (dof_increment(iof+i), i=0,node_list(n)%n_dof-1), &
                            (dof_total(iof+i), i=0,node_list(n)%n_dof-1), &
                            (field_variables(i,n), i=1,n_field_variables)
              else if (print_dof) then
                 iof = node_list(n)%dof_index
                 write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (dof_increment(iof+i), i=0,node_list(n)%n_dof-1), &
                            (dof_total(iof+i), i=0,node_list(n)%n_dof-1)
              else if (ntotalvars>0) then
                 iof = node_list(n)%dof_index
                 write (state_print_unit, format_string) (xx(i), i=1,node_list(n)%n_coords), &
                            (field_variables(i,n), i=1,n_field_variables)
              endif

           endif
        end do

    
        node_numbers = -node_numbers             ! Remove the - flag that suppresses duplicate prints from node numbers

        ! Print the elements

        do lmn = zone_list(iz)%start_element,zone_list(iz)%end_element
            jp = element_list(lmn)%connect_index
            auxiliary_node = n_printable_nodes
            if (zone_dimension(iz)==2) then
                if ( element_list(lmn)%n_nodes==9 ) then
                    write (state_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 3))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 4))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 4)),  &
                        node_numbers(connectivity(jp + 7)), &
                        node_numbers(connectivity(jp + 6))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 5)),  &
                        node_numbers(connectivity(jp + 8)), &
                        node_numbers(connectivity(jp + 7))
                else if ( element_list(lmn)%n_nodes==8 ) then
                    auxiliary_node = auxiliary_node + 1
                    write (state_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 4)), &
                        auxiliary_node, &
                        node_numbers(connectivity(jp + 7))
                    write (state_print_unit, *) node_numbers(connectivity(jp+4)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 5)), &
                        auxiliary_node
                    write (state_print_unit, *) auxiliary_node, &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 6))
                    write (state_print_unit, *) node_numbers(connectivity(jp+7)), &
                        auxiliary_node, &
                        node_numbers(connectivity(jp + 6)), &
                        node_numbers(connectivity(jp + 3))
                else if ( element_list(lmn)%n_nodes==6 ) then
                    write (state_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 1)),  &
                        node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 4))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 4)), &
                        node_numbers(connectivity(jp + 2)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                    write (state_print_unit, *) node_numbers(connectivity(jp + 3)), &
                        node_numbers(connectivity(jp + 4)),  &
                        node_numbers(connectivity(jp + 5)), &
                        node_numbers(connectivity(jp + 5))
                else if ( element_list(lmn)%n_nodes==4 ) then
                    write (state_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 3))
                else if ( element_list(lmn)%n_nodes==3 ) then
                    write (state_print_unit, *) node_numbers(connectivity(jp)), &
                        node_numbers(connectivity(jp + 1)), &
                        node_numbers(connectivity(jp + 2)), &
                        node_numbers(connectivity(jp + 2))
                endif
            else if (zone_dimension(iz)==3) then
                if (element_list(lmn)%n_nodes==8) then
                    write(state_print_unit,'(8(1x,i5))') (node_numbers(connectivity(jp+k)), k=0,7)
                end if
                if (element_list(lmn)%n_nodes ==4) then
                    write(state_print_unit,'(4(1x,i5))') (node_numbers(connectivity(jp+k)), k=0,3)
                endif
            endif
        end do
    end do


    if (n_field_variables>0) then
        deallocate(lumped_projection_matrix)
        deallocate(field_variables)
        deallocate(auxiliary_field_variables)
    endif
    deallocate(auxiliary_dof)
    deallocate(auxiliary_dof_increment)
    deallocate(node_numbers)

end subroutine print_state
!

subroutine assemble_projection_mass_matrix(start_element,end_element,lumped_projection_matrix)
    use Types
    use ParamIO
    use Element_Utilities, only : N3 => shape_functions_3D
    use Element_Utilities, only : dNdxi3 => shape_function_derivatives_3D
    use Element_Utilities, only : dNdx3 => shape_function_spatial_derivatives_3D
    use Element_Utilities, only : xi3 => integrationpoints_3D, w3 => integrationweights_3D
    use Element_Utilities, only : dxdxi3 => jacobian_3D
    use Element_Utilities, only : N2 => shape_functions_2D
    use Element_Utilities, only : dNdxi2 => shape_function_derivatives_2D
    use Element_Utilities, only : dNdx2 => shape_function_spatial_derivatives_2D
    use Element_Utilities, only : xi2 => integrationpoints_2D, w2 => integrationweights_2D
    use Element_Utilities, only : dxdxi2 => jacobian_2D
    use Element_Utilities, only : initialize_integration_points
    use Element_Utilities, only : calculate_shapefunctions
    use Mesh, only:  n_nodes, element,node, connectivity, element_list,node_list, coords

    implicit none

    integer, intent( in )                    :: start_element
    integer, intent( in )                    :: end_element

    real( prec ), intent( out )              :: lumped_projection_matrix(n_nodes)

    ! Local Variables
    logical      :: twoD, threeD
         
    integer      :: j, lmn, kint
    integer      :: n,nnodlmn
    integer      :: n_points
         
    real (prec) :: x2D(2,9)
    real (prec) :: x3D(3,20)
    real (prec) :: determinant


    !     Assemble a lumped projection matrix for a zone

    lumped_projection_matrix = 0.d0
    twoD = .false.
    threeD = .false.

    do lmn = start_element,end_element

        do j = 1, element_list(lmn)%n_nodes
            n = connectivity(element_list(lmn)%connect_index + j - 1)
            if (node_list(n)%n_coords==2) twoD = .true.
            if (node_list(n)%n_coords==3) threeD = .true.
        end do
          
        if (twoD.and.threeD) cycle               ! Skip nonstandard element
        if (.not.twoD .and. .not.threeD) cycle   ! Skip nonstandard element

        if (twoD) then
            nnodlmn = element_list(lmn)%n_nodes
            if (nnodlmn>9) cycle                                !Nonstandard element
            do j = 1, nnodlmn
                n = connectivity(element_list(lmn)%connect_index + j - 1)
                x2D(1,j) = coords(node_list(n)%coord_index)
                x2D(2,j) = coords(node_list(n)%coord_index+1)
            end do
            n_points = 0
            if (nnodlmn == 3) n_points = 4
            if (nnodlmn == 4) n_points = 4
            if (nnodlmn == 6) n_points = 7
            if (nnodlmn == 8) n_points = 9
            if (nnodlmn == 9) n_points = 9
            if (n_points==0) cycle                             ! Nonstandard element
            call initialize_integration_points(n_points, nnodlmn, xi2, w2)
             
            do kint = 1,n_points
             
                call calculate_shapefunctions(xi2(1:2,kint),nnodlmn,N2,dNdxi2)      
                dxdxi2 = matmul(x2D(1:2,1:nnodlmn),dNdxi2(1:nnodlmn,1:2))
                determinant = dxdxi2(1,1)*dxdxi2(2,2) - dxdxi2(2,1)*dxdxi2(1,2)
                !             Lumped projection matrix computed using row sum of consistent mass matrix
                do j = 1,nnodlmn
                    n = connectivity(element_list(lmn)%connect_index + j - 1)
                    lumped_projection_matrix(n) = lumped_projection_matrix(n) + N2(j)*sum(N2(1:nnodlmn))*determinant*w2(kint)
                end do
                
            end do

        else if (threeD) then
            nnodlmn = element_list(lmn)%n_nodes
            do j = 1, nnodlmn
                n = connectivity(element_list(lmn)%connect_index + j - 1)
                x3D(1,j) = coords(node_list(n)%coord_index)
                x3D(2,j) = coords(node_list(n)%coord_index+1)
                x3D(3,j) = coords(node_list(n)%coord_index+2)
            end do
            n_points = 0
            if (nnodlmn == 4) n_points = 4
            if (nnodlmn == 10) n_points = 5
            if (nnodlmn == 8) n_points = 27
            if (nnodlmn == 20) n_points = 27
            if (n_points==0) cycle                                 ! Nonstandard element
            call initialize_integration_points(n_points, nnodlmn, xi3, w3)
            do kint = 1,n_points
                call calculate_shapefunctions(xi3(1:3,kint),nnodlmn,N3,dNdxi3)      
                dxdxi3 = matmul(x3D(1:3,1:nnodlmn),dNdxi3(1:nnodlmn,1:3))
                determinant =   dxdxi3(1,1)*dxdxi3(2,2)*dxdxi3(3,3)  &
                    - dxdxi3(1,1)*dxdxi3(2,3)*dxdxi3(3,2)  &
                    - dxdxi3(1,2)*dxdxi3(2,1)*dxdxi3(3,3)  &
                    + dxdxi3(1,2)*dxdxi3(2,3)*dxdxi3(3,1)  &
                    + dxdxi3(1,3)*dxdxi3(2,1)*dxdxi3(3,2)  &
                    - dxdxi3(1,3)*dxdxi3(2,2)*dxdxi3(3,1)
                !             Lumped projection matrix computed  using row sum method
                do j = 1,nnodlmn
                    n = connectivity(element_list(lmn)%connect_index + j - 1)
                    lumped_projection_matrix(n) = lumped_projection_matrix(n) + N3(j)*sum(N3(1:nnodlmn))*determinant*w3(kint)
                end do
                
            end do
        endif

    end do
  
end subroutine assemble_projection_mass_matrix
   
   
subroutine assemble_field_projection(start_element,end_element,n_field_variables,field_variable_names,field_variables)
    use Types
    use ParamIO
    use User_Subroutine_Storage
    use Mesh
    implicit none
  
    integer, intent(in)              :: start_element
    integer, intent(in)              :: end_element
    integer, intent(in)              :: n_field_variables
  
    character (len=100), intent(in)  :: field_variable_names(n_field_variables)
  
    real(prec), intent(inout)      :: field_variables(n_field_variables,n_nodes)

    ! Local Variables
    integer      :: iu, ix, j,k
    integer      ::  lmn, n
    integer      :: iof, ns

    real( prec )    :: element_coords(length_coord_array)
    real( prec )    :: element_dof_increment(length_dof_array)
    real( prec )    :: element_dof_total(length_dof_array)

    type (node) local_nodes(length_node_array)
  
    real (prec) :: nodal_field_variables(n_field_variables,length_node_array)

    !     Subroutine to assemble global stiffness matrix



    do lmn = start_element,end_element

        !     Extract local coords, DOF and nodal state/props for the element
        ix = 0
        iu = 0
        do j = 1, element_list(lmn)%n_nodes
            n = connectivity(element_list(lmn)%connect_index + j - 1)
            local_nodes(j)%n_coords = node_list(n)%n_coords
            local_nodes(j)%coord_index = ix+1
            do k = 1, node_list(n)%n_coords
                ix = ix + 1
                element_coords(ix) = coords(node_list(n)%coord_index + k - 1)
            end do
            local_nodes(j)%dof_index = iu+1
            do k = 1, node_list(n)%n_dof
                iu = iu + 1
                element_dof_increment(iu) = dof_increment(node_list(n)%dof_index + k - 1)
                element_dof_total(iu) = dof_total(node_list(n)%dof_index + k - 1)
            end do
        end do

        !     Get element contribution to nodal state
        iof = element_list(lmn)%state_index
        if (iof==0) iof = 1
        ns = element_list(lmn)%n_states

        call user_element_fieldvariables(lmn, element_list(lmn)%flag, element_list(lmn)%n_nodes, local_nodes, &       ! Input variables
            element_list(lmn)%n_element_properties, element_properties(element_list(lmn)%element_property_index),  &  ! Input variables
            element_coords, element_dof_increment, element_dof_total,      &                                          ! Input variables
            ns, initial_state_variables(iof:iof+ns),updated_state_variables(iof:iof+ns), &                            ! Input variables
            n_field_variables,field_variable_names, &                                                           ! Field variable definition
            nodal_field_variables)      ! Output variables

        do j = 1, element_list(lmn)%n_nodes
            n = connectivity(element_list(lmn)%connect_index + j - 1)
            field_variables(1:n_field_variables,n) = &
                           field_variables(1:n_field_variables,n)+nodal_field_variables(1:n_field_variables,j)
        end do
    end do
   
   
end subroutine assemble_field_projection
